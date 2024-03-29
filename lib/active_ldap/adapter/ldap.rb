require 'active_ldap/adapter/base'

module ActiveLdap
  module Adapter
    class Base
      class << self
        def ldap_connection(options)
          unless defined?(::LDAP)
            require 'active_ldap/adapter/ldap_ext'
          end
          Ldap.new(options)
        end
      end
    end

    class Ldap < Base
      module Method
        class SSL
          def connect(host, port)
            LDAP::SSLConn.new(host, port, false)
          end
        end

        class TLS
          def connect(host, port)
            LDAP::SSLConn.new(host, port, true)
          end
        end

        class Plain
          def connect(host, port)
            LDAP::Conn.new(host, port)
          end
        end
      end

      def connect(options={})
        super do |host, port, method|
          method.connect(host, port)
        end
      end

      def unbind(options={})
        return unless bound?
        operation(options) do
          execute(:unbind)
        end
      end

      def bind(options={})
        super do
          @connection.error_message
        end
      end

      def bind_as_anonymous(options={})
        super do
          execute(:bind)
          true
        end
      end

      def bound?
        connecting? and @connection.bound?
      end

      def search(options={}, &block)
        super(options) do |base, scope, filter, attrs, limit, callback|
          begin
            i = 0
            execute(:search, base, scope, filter, attrs) do |entry|
              i += 1
              attributes = {}
              entry.attrs.each do |attr|
                attributes[attr] = entry.vals(attr)
              end
              callback.call([entry.dn, attributes], block)
              break if limit and limit <= i
            end
          rescue RuntimeError
            if $!.message == "no result returned by search"
              @logger.debug do
                args = [filter, attrs.inspect]
                _("No matches: filter: %s: attributes: %s") % args
              end
            else
              raise
            end
          end
        end
      end

      def to_ldif(dn, attributes)
        ldif = LDAP::LDIF.to_ldif("dn", [dn.dup])
        attributes.sort_by do |key, value|
          key
        end.each do |key, values|
          ldif << LDAP::LDIF.to_ldif(key, values)
        end
        ldif
      end

      def load(ldifs, options={})
        super do |ldif|
          LDAP::LDIF.parse_entry(ldif).send(@connection)
        end
      end

      def delete(targets, options={})
        super do |target|
          execute(:delete, target)
        end
      end

      def add(dn, entries, options={})
        super do |dn, entries|
          execute(:add, dn, parse_entries(entries))
        end
      end

      def modify(dn, entries, options={})
        super do |dn, entries|
          execute(:modify, dn, parse_entries(entries))
        end
      end

      private
      def prepare_connection(options={})
        operation(options) do
          @connection.set_option(LDAP::LDAP_OPT_PROTOCOL_VERSION, 3)
        end
      end

      def root_dse(attributes, options={})
        sec = options[:sec] || 0
        usec = options[:usec] || 0
        @connection.root_dse(attributes, sec, usec)
      end

      def execute(method, *args, &block)
        begin
          @connection.send(method, *args, &block)
        rescue LDAP::ResultError
          @connection.assert_error_code
          raise $!.message
        end
      end

      def with_timeout(try_reconnect=true, options={}, &block)
        begin
          super
        rescue LDAP::ServerDown => e
          @logger.error {_("LDAP server is down: %s") % e.message}
          retry if try_reconnect and reconnect(options)
          raise ConnectionError.new(e.message)
        end
      end

      def ensure_method(method)
        Method.constants.each do |name|
          if method.to_s.downcase == name.downcase
            return Method.const_get(name).new
          end
        end

        available_methods = Method.constants.collect do |name|
          name.downcase.to_sym.inspect
        end.join(", ")
        format = _("%s is not one of the available connect methods: %s")
        raise ConfigurationError, format % [method.inspect, available_methods]
      end

      def ensure_scope(scope)
        scope_map = {
          :base => LDAP::LDAP_SCOPE_BASE,
          :sub => LDAP::LDAP_SCOPE_SUBTREE,
          :one => LDAP::LDAP_SCOPE_ONELEVEL,
        }
        value = scope_map[scope || :sub]
        if value.nil?
          available_scopes = scope_map.keys.inspect
          format = _("%s is not one of the available LDAP scope: %s")
          raise ArgumentError, format % [scope.inspect, available_scopes]
        end
        value
      end

      def sasl_bind(bind_dn, options={})
        super do |bind_dn, mechanism, quiet|
          begin
            sasl_quiet = @connection.sasl_quiet
            @connection.sasl_quiet = quiet unless quiet.nil?
            args = [bind_dn, mechanism]
            if need_credential_sasl_mechanism?(mechanism)
              args << password(bind_dn, options)
            end
            execute(:sasl_bind, *args)
          ensure
            @connection.sasl_quiet = sasl_quiet
          end
        end
      end

      def simple_bind(bind_dn, options={})
        super do |bind_dn, passwd|
          execute(:bind, bind_dn, passwd)
        end
      end

      def parse_entries(entries)
        result = []
        entries.each do |type, key, attributes|
          mod_type = ensure_mod_type(type)
          binary = schema.attribute(key).binary?
          mod_type |= LDAP::LDAP_MOD_BVALUES if binary
          attributes.each do |name, values|
            result << LDAP.mod(mod_type, name, values)
          end
        end
        result
      end

      def ensure_mod_type(type)
        case type
        when :replace, :add
          LDAP.const_get("LDAP_MOD_#{type.to_s.upcase}")
        else
          raise ArgumentError, _("unknown type: %s") % type
        end
      end
    end
  end
end
