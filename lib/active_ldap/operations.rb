module ActiveLdap
  module Operations
    class << self
      def included(base)
        super
        base.class_eval do
          extend(Common)
          extend(Find)
          extend(LDIF)
          extend(Delete)
          extend(Update)

          include(Common)
          include(Find)
          include(LDIF)
          include(Delete)
          include(Update)
        end
      end
    end

    module Common
      VALID_SEARCH_OPTIONS = [:attribute, :value, :filter, :prefix,
                              :classes, :scope, :limit, :attributes,
                              :sort_by, :order, :connection]

      def search(options={}, &block)
        validate_search_options(options)
        attr = options[:attribute]
        value = options[:value] || '*'
        filter = options[:filter]
        prefix = options[:prefix]
        classes = options[:classes]

        value = value.first if value.is_a?(Array) and value.first.size == 1
        if filter.nil? and !value.is_a?(String)
          message = _("Search value must be a String: %s") % value.inspect
          raise ArgumentError, message
        end

        _attr, value, _prefix = split_search_value(value)
        attr ||= _attr || dn_attribute || "objectClass"
        prefix ||= _prefix
        filter ||= [attr, value]
        filter = [:and, filter, *object_class_filters(classes)]
        _base = [prefix, base].compact.reject{|x| x.empty?}.join(",")
        if options.has_key?(:ldap_scope)
          logger.warning do
            _(":ldap_scope search option is deprecated. Use :scope instead.")
          end
          options[:scope] ||= options[:ldap_scope]
        end
        search_options = {
          :base => _base,
          :scope => options[:scope] || scope,
          :filter => filter,
          :limit => options[:limit],
          :attributes => options[:attributes],
          :sort_by => options[:sort_by],
          :order => options[:order],
        }

        conn = options[:connection] || connection
        conn.search(search_options) do |dn, attrs|
          attributes = {}
          attrs.each do |key, value|
            normalized_attr, normalized_value =
              normalize_attribute_options(key, value)
            attributes[normalized_attr] ||= []
            attributes[normalized_attr].concat(normalized_value)
          end
          value = [dn, attributes]
          value = yield(value) if block_given?
          value
        end
      end

      def exist?(dn, options={})
        attr, value, prefix = split_search_value(dn)

        options_for_leaf = {
          :attribute => attr,
          :value => value,
          :prefix => prefix,
        }

        attribute = attr || dn_attribute || "objectClass"
        options_for_non_leaf = {
          :attribute => attr,
          :value => value,
          :prefix => ["#{attribute}=#{value}", prefix].compact.join(","),
          :scope => :base,
        }

        !search(options_for_leaf.merge(options)).empty? or
          !search(options_for_non_leaf.merge(options)).empty?
      end
      alias_method :exists?, :exist?

      def count(options={})
        search(options).size
      end

      private
      def validate_search_options(options)
        options.assert_valid_keys(VALID_SEARCH_OPTIONS)
      end

      def extract_options_from_args!(args)
        args.last.is_a?(Hash) ? args.pop : {}
      end

      def ensure_dn_attribute(target)
        "#{dn_attribute}=" +
          target.gsub(/^\s*#{Regexp.escape(dn_attribute)}\s*=\s*/i, '')
      end

      def ensure_base(target)
        [truncate_base(target),  base].join(',')
      end

      def truncate_base(target)
        if /,/ =~ target
          begin
            (DN.parse(target) - DN.parse(base)).to_s
          rescue DistinguishedNameInvalid, ArgumentError
            target
          end
        else
          target
        end
      end

      def object_class_filters(classes=nil)
        (classes || required_classes).collect do |name|
          ["objectClass", Escape.ldap_filter_escape(name)]
        end
      end

      def split_search_value(value)
        attr = prefix = nil
        begin
          dn = DN.parse(value)
          attr, value = dn.rdns.first.to_a.first
          rest = dn.rdns[1..-1]
          prefix = DN.new(*rest).to_s unless rest.empty?
        rescue DistinguishedNameInvalid
          begin
            dn = DN.parse("DUMMY=#{value}")
            _, value = dn.rdns.first.to_a.first
            rest = dn.rdns[1..-1]
            prefix = DN.new(*rest).to_s unless rest.empty?
          rescue DistinguishedNameInvalid
          end
        end

        prefix = nil if prefix == base
        prefix = truncate_base(prefix) if prefix
        [attr, value, prefix]
      end
    end

    module Find
      # find
      #
      # Finds the first match for value where |value| is the value of some
      # |field|, or the wildcard match. This is only useful for derived classes.
      # usage: Subclass.find(:attribute => "cn", :value => "some*val")
      #        Subclass.find('some*val')
      def find(*args)
        options = extract_options_from_args!(args)
        args = [:first] if args.empty? and !options.empty?
        case args.first
        when :first
          find_initial(options)
        when :all
          options[:value] ||= args[1]
          find_every(options)
        else
          find_from_dns(args, options)
        end
      end

      private
      def find_initial(options)
        find_every(options.merge(:limit => 1)).first
      end

      def normalize_sort_order(value)
        case value.to_s
        when /\Aasc(?:end)?\z/i
          :ascend
        when /\Adesc(?:end)?\z/i
          :descend
        else
          raise ArgumentError, _("Invalid order: %s") % value.inspect
        end
      end

      def find_every(options)
        options = options.dup
        sort_by = options.delete(:sort_by)
        order = options.delete(:order)
        limit = options.delete(:limit) if sort_by or order

        results = search(options).collect do |dn, attrs|
          instantiate([dn, attrs, {:connection => options[:connection]}])
        end
        return results if sort_by.nil? and order.nil?

        sort_by ||= "dn"
        if sort_by.downcase == "dn"
          results = results.sort_by {|result| DN.parse(result.dn)}
        else
          results = results.sort_by {|result| result.send(sort_by)}
        end

        results.reverse! if normalize_sort_order(order || "ascend") == :descend
        results = results[0, limit] if limit
        results
      end

      def find_from_dns(dns, options)
        expects_array = dns.first.is_a?(Array)
        return [] if expects_array and dns.first.empty?

        dns = dns.flatten.compact.uniq

        case dns.size
        when 0
          raise EntryNotFound, _("Couldn't find %s without a DN") % name
        when 1
          result = find_one(dns.first, options)
          expects_array ? [result] : result
        else
          find_some(dns, options)
        end
      end

      def find_one(dn, options)
        attr, value, prefix = split_search_value(dn)
        filter = [attr || dn_attribute, Escape.ldap_filter_escape(value)]
        filter = [:and, filter, options[:filter]] if options[:filter]
        options = {:prefix => prefix}.merge(options.merge(:filter => filter))
        result = find_initial(options)
        if result
          result
        else
          args = [name, dn]
          if options[:filter]
            format = _("Couldn't find %s: DN: %s: filter: %s")
            args << options[:filter].inspect
          else
            format = _("Couldn't find %s: DN: %s")
          end
          raise EntryNotFound, format % args
        end
      end

      def find_some(dns, options)
        dn_filters = dns.collect do |dn|
          attr, value, prefix = split_search_value(dn)
          attr ||= dn_attribute
          filter = [attr, value]
          if prefix
            filter = [:and,
                      filter,
                      [dn, "*,#{Escape.ldap_filter_escape(prefix)},#{base}"]]
          end
          filter
        end
        filter = [:or, *dn_filters]
        filter = [:and, filter, options[:filter]] if options[:filter]
        result = find_every(options.merge(:filter => filter))
        if result.size == dns.size
          result
        else
          args = [name, dns.join(', ')]
          if options[:filter]
            format = _("Couldn't find all %s: DNs (%s): filter: %s")
            args << options[:filter].inspect
          else
            format = _("Couldn't find all %s: DNs (%s)")
          end
          raise EntryNotFound, format % args
        end
      end

      def ensure_dn(target)
        attr, value, prefix = split_search_value(target)
        "#{attr || dn_attribute}=#{value},#{prefix || base}"
      end
    end

    module LDIF
      def dump(options={})
        ldifs = []
        options = {:base => base, :scope => scope}.merge(options)
        conn = options[:connection] || connection
        conn.search(options) do |dn, attributes|
          ldifs << to_ldif(dn, attributes)
        end
        ldifs.join("\n")
      end

      def to_ldif(dn, attributes, options={})
        conn = options[:connection] || connection
        conn.to_ldif(dn, unnormalize_attributes(attributes))
      end

      def load(ldifs, options={})
        conn = options[:connection] || connection
        conn.load(ldifs)
      end
    end

    module Delete
      def destroy(targets, options={})
        targets = [targets] unless targets.is_a?(Array)
        targets.each do |target|
          find(target, options).destroy
        end
      end

      def destroy_all(filter=nil, options={})
        targets = []
        if filter.is_a?(Hash)
          options = options.merge(filter)
          filter = nil
        end
        options = options.merge(:filter => filter) if filter
        find(:all, options).sort_by do |target|
          target.dn.reverse
        end.reverse.each do |target|
          target.destroy
        end
      end

      def delete(targets, options={})
        targets = [targets] unless targets.is_a?(Array)
        targets = targets.collect do |target|
          ensure_dn_attribute(ensure_base(target))
        end
        conn = options[:connection] || connection
        conn.delete(targets, options)
      end

      def delete_all(filter=nil, options={})
        options = {:base => base, :scope => scope}.merge(options)
        options = options.merge(:filter => filter) if filter
        conn = options[:connection] || connection
        targets = conn.search(options).collect do |dn, attributes|
          dn
        end.sort_by do |dn|
          dn.upcase.reverse
        end.reverse

        conn.delete(targets)
      end
    end

    module Update
      def add_entry(dn, attributes, options={})
        unnormalized_attributes = attributes.collect do |type, key, value|
          [type, key, unnormalize_attribute(key, value)]
        end
        conn = options[:connection] || connection
        conn.add(dn, unnormalized_attributes, options)
      end

      def modify_entry(dn, attributes, options={})
        unnormalized_attributes = attributes.collect do |type, key, value|
          [type, key, unnormalize_attribute(key, value)]
        end
        conn = options[:connection] || connection
        conn.modify(dn, unnormalized_attributes, options)
      end

      def update(dn, attributes, options={})
        if dn.is_a?(Array)
          i = -1
          dns = dn
          dns.collect do |dn|
            i += 1
            update(dn, attributes[i], options)
          end
        else
          object = find(dn, options)
          object.update_attributes(attributes)
          object
        end
      end

      def update_all(attributes, filter=nil, options={})
        search_options = options.dup
        if filter
          if filter.is_a?(String) and /[=\(\)&\|]/ !~ filter
            search_options = search_options.merge(:value => filter)
          else
            search_options = search_options.merge(:filter => filter)
          end
        end
        targets = search(search_options).collect do |dn, attrs|
          dn
        end

        unnormalized_attributes = attributes.collect do |name, value|
          normalized_name, normalized_value = normalize_attribute(name, value)
          [:replace, normalized_name,
           unnormalize_attribute(normalized_name, normalized_value)]
        end
        conn = options[:connection] || connection
        targets.each do |dn|
          conn.modify(dn, unnormalized_attributes, options)
        end
      end
    end
  end
end
