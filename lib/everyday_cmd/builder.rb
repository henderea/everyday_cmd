module EverydayCmd
  module BuilderBuildItems
    class RuntimeEnv
      def initialize(root_command, parent, command, global)
        @root_command = root_command
        @parent       = parent
        @command      = command
        @global       = global

        @global.helpers.helpers.keys.each { |hn| self.define_singleton_method(hn.to_sym, @global.helpers[hn]) }
        @parent.helpers.helpers.keys.each { |hn| self.define_singleton_method(hn.to_sym, @parent.helpers[hn]) }
        @command.helpers.helpers.keys.each { |hn| self.define_singleton_method(hn.to_sym, @command.helpers[hn]) }
      end

      def call_command(orig_name_chain, *args)
        name_chain = orig_name_chain.clone
        start      = name_chain.first == @root_command.name ? @root_command : @parent
        c          = start
        cn         = nil
        until c.nil? || c.leaf? || name_chain.empty?
          cn = name_chain.shift
          c  = c[cn]
        end
        if c.nil?
          puts "Command #{start.name_chain.join(' ')} #{orig_name_chain[0..(-name_chain.count)].map(&:to_s).join(' ')} #{cn} does not exist!"
          exit 1
        else
          # c.body.bind(self).call(*args)
          re = EverydayCmd::BuilderBuildItems::RuntimeEnv.new(@root_command, c.parent, c, @global)
          re.instance_exec(*args, &c.body)
        end
      end
    end
    class BuilderCommand
      def initialize(parent = nil, options = {}, &block)
        @aliases = options.delete(:aliases) if options.has_key?(:aliases) && !parent.nil?
        @parent  = parent
        @options = options
        @body    = block
      end

      def parent
        @parent
      end

      def body
        @body
      end

      def options
        @options
      end

      def define(&block)
        block.call(self)
      end

      def aliases
        @aliases ||= []
      end

      def commands
        @commands ||= EverydayCmd::BuilderBuildLists::BuilderCommands.new(self)
      end

      def flags
        @flags ||= EverydayCmd::BuilderBuildLists::BuilderFlags.new(self)
      end

      def helpers
        @helpers ||= EverydayCmd::BuilderBuildLists::BuilderHelpers.new(self)
      end

      def leaf?
        self.commands.commands.empty?
      end

      def has_alias?(name)
        self.aliases.any? { |a| name_matches(name, a) }
      end

      def name_matches(name, other_name)
        #update with matching schema
        name == other_name
      end

      def [](name)
        if self.commands.has_key?(name)
          self.commands[name]
        elsif self.helpers.has_key?(name)
          self.helpers[name]
        elsif self.flags.has_key?(name)
          self.flags[name]
        else
          nil
        end
      end

      def []=(name, obj)
        if obj.is_a?(Hash)
          self.flags[name] = obj
        elsif obj.is_a?(BuilderCommand)
          self.commands[name] = obj
        elsif obj.is_a?(Proc)
          self.helpers[name] = obj
        end
      end
    end
    class BuilderCommandContext < BuilderCommand
      def initialize(parent_context, name, wrapped_command)
        @parent_context  = parent_context
        @name            = name
        @wrapped_command = wrapped_command
      end

      def name
        @name
      end

      def name_chain
        (self.parent.nil? ? [] : self.parent.name_chain) + [self.name.to_s]
      end

      def parent
        @parent_context
      end

      def body
        @wrapped_command.body
      end

      def options
        @wrapped_command.options
      end

      def define(&block)
        @wrapped_command.define(&block)
      end

      def aliases
        @wrapped_command.aliases
      end

      def commands
        EverydayCmd::BuilderBuildLists::BuilderCommandsContext.new(self, @wrapped_command.commands)
      end

      def flags
        @wrapped_command.flags
      end

      def helpers
        @wrapped_command.helpers
      end

      def leaf?
        @wrapped_command.leaf?
      end

      def has_alias?(name)
        @wrapped_command.has_alias?(name)
      end

      def [](name)
        self.commands.has_key?(name) ? self.commands[name] : @wrapped_command[name]
      end

      def []=(name, obj)
        @wrapped_command[name] = obj
      end
    end
    class BuilderGlobal
      def helpers
        @helpers ||= EverydayCmd::BuilderBuildLists::BuilderHelpers.new(self)
      end
    end
  end
  module BuilderBuildLists
    class BuilderHelpers
      def initialize(parent)
        @parent  = parent
        @helpers = {}
      end

      def helpers
        @helpers
      end

      def [](name)
        @helpers[name.to_sym]
      end

      def []=(name, body)
        if body.nil?
          self.delete(name)
          nil
        else
          @helpers[name.to_sym] = body
        end
      end

      def has_key?(name)
        @helpers.has_key?(name.to_sym)
      end

      def delete(name)
        @helpers.delete(name.to_sym)
      end
    end
    class BuilderFlags
      def initialize(parent)
        @parent = parent
        @flags  = {}
      end

      def flags
        @flags
      end

      def [](name)
        @flags[name.to_sym] || @flags.select { |f| f.has_key?(:aliases) && f[:aliases] && (f[:aliases].include?(name.to_s) || f[:aliases].include?(name.to_sym)) }.first
      end

      def []=(name, flag)
        if flag.nil?
          self.delete(name)
          nil
        else
          @flags[name.to_sym] = flag
        end
      end

      def has_key?(name)
        @flags.has_key?(name.to_sym)
      end

      def delete(name)
        @flags.delete(name.to_sym)
      end
    end
    class BuilderCommands
      def initialize(parent)
        @parent   = parent
        @commands = {}
      end

      def commands
        @commands
      end

      def each(&block)
        self.commands.keys.each { |k| block.call(k.to_sym, self[k]) } if block
      end

      def map(&block)
        self.commands.keys.map { |k| block.call(k.to_sym, self[k]) } if block
      end

      def [](name)
        @commands[name.to_sym] || @commands.select { |c| c.has_alias?(name) }.first
      end

      def []=(name, command)
        if command.nil?
          delete(name)
          nil
        else
          @commands[name.to_sym] = EverydayCmd::BuilderBuildItems::BuilderCommand.new(@parent, command.options, &command.body)
        end
      end

      def has_key?(name)
        @commands.has_key?(name.to_sym) || @commands.any? { |c| c.has_alias?(name) }
      end

      def delete(name)
        @commands.delete(name.to_sym)
      end
    end
    class BuilderCommandsContext < EverydayCmd::BuilderBuildLists::BuilderCommands
      def initialize(parent_context, wrapped_list)
        @parent_context = parent_context
        @wrapped_list   = wrapped_list
      end

      def commands
        { :help => nil, ** @wrapped_list.commands }
      end

      def [](name)
        if name.to_sym == :help
          EverydayCmd::BuilderBuildItems::BuilderCommand.new(@parent_context, short_desc: 'help [command_name]', desc: 'show help on this command or a child') { |name = nil|
            if name && @parent.commands.has_key?(name) && @parent.commands[name].leaf?
              puts "display full help for #{@parent.name_chain.join(' ')} #{name}"
            elsif name
              call_command([name, :help])
            else
              ml = @parent.commands.map { |_, c|
                "#{@parent.name_chain.join(' ')} #{name} #{c.options[:short_desc]}".length
              }.max
              @parent.commands.each { |_, c|
                "#{"#{@parent.name_chain.join(' ')} #{name} #{c.options[:short_desc]}".ljust(ml)}    #{c.options[:desc]}"
              }
            end
          }
        else
          wc = @wrapped_list[name]
          wc && EverydayCmd::BuilderBuildItems::BuilderCommandContext.new(@parent_context, name.to_sym, wc)
        end
      end

      def []=(name, command)
        @wrapped_list[name] = command
      end

      def has_key?(name)
        name.to_sym == :help || @wrapped_list.has_key?(name)
      end

      def delete(name)
        @wrapped_list.delete(name)
      end
    end
  end
  class BuilderDataStore
    class << self
      def instance
        @instance ||= EverydayCmd::BuilderDataStore.new
      end
    end

    def global
      @global ||= EverydayCmd::BuilderBuildItems::BuilderGlobal.new
    end

    def root_command
      @root_command ||= EverydayCmd::BuilderBuildItems::BuilderCommand.new
    end
  end
  class Runner
    def initialize(root_command, global)
      @root_command = EverydayCmd::BuilderBuildItems::BuilderCommandContext.new(nil, 'cmd', root_command)
      @global       = global
    end

    def run(orig_args)
      args = orig_args.clone
      c    = @root_command
      cn   = nil
      until c.nil? || c.leaf? || args.empty?
        cn = args.shift
        c  = c[cn]
      end
      if c.nil?
        puts "Could not find command #{cn}"
        exit 1
      else
        env = EverydayCmd::BuilderBuildItems::RuntimeEnv.new(@root_command, c.parent, c, global)
        env.instance_exec(*args, &c.body)
      end
    end
  end
  module Builder
    def global
      EverydayCmd::BuilderDataStore.instance.global
    end

    def root_command
      EverydayCmd::BuilderDataStore.instance.root_command
    end

    def flag(opts = {})
      opts
    end

    def command(options = {}, &block)
      EverydayCmd::BuilderBuildItems::BuilderCommand.new(nil, options, &block)
    end

    def run!(args = ARGV)
      EverydayCmd::Runner.new(self.root_command, self.global).run(args)
    end

    # def build!
    #   rc = Class.new(Thor)
    #   build_recurse(self.root_command, rc)
    #   rc
    # end
    #
    # def build_helpers(p, pc)
    #   self.global.helpers.helpers.each { |hn, h| pc.no_commands { pc.create_method(hn.to_sym, &h) } }
    #   p.helpers.helpers.each { |hn, h| pc.no_commands { pc.create_method(hn.to_sym, &h) } }
    # end
    #
    # def build_flags(p, pc, has_children)
    #   p.flags.flags.each { |fn, f| has_children ? pc.class_option(fn.to_sym, f) : pc.option(fn.to_sym, f) }
    # end
    #
    # def build_recurse(p, pc)
    #   if p.parent.nil?
    #     build_flags(p, pc, true)
    #     build_helpers(p, pc)
    #   end
    #   p.commands.commands.each { |cn, c|
    #     short_desc = c.options[:short_desc]
    #     desc      = c.options[:desc]
    #     long_desc = c.options[:long_desc]
    #     aliases   = c.aliases
    #     if !c.leaf?
    #       cc = Class.new(Thor)
    #       cc.namespace cn.to_s
    #       build_helpers(c, cc)
    #       build_flags(c, cc, true)
    #       build_recurse(c, cc)
    #       build_flags(c, pc, false)
    #       pc.desc short_desc, desc if short_desc && desc
    #       pc.long_desc long_desc if long_desc
    #       pc.subcommand cn, cc
    #       aliases.each { |an|
    #         cc2 = Class.new(Thor)
    #         cc2.namespace an
    #         build_helpers(c, cc2)
    #         build_flags(c, cc2, true)
    #         build_recurse(c, cc2)
    #         build_flags(c, pc, false)
    #         pc.desc short_desc.gsub(/^\S+(?=\s|$)/, an.gsub(/_/, '-')), desc if short_desc && desc
    #         pc.long_desc long_desc if long_desc
    #         pc.subcommand an, cc2
    #       } if aliases && !aliases.empty?
    #     elsif c.body
    #       build_flags(c, pc, false)
    #       pc.desc short_desc, desc if short_desc && desc
    #       pc.long_desc long_desc if long_desc
    #       pc.create_method(cn.to_sym, &c.body)
    #       aliases.each { |an|
    #         build_flags(c, pc, false)
    #         pc.desc short_desc.gsub(/^\S+(?=\s|$)/, an.gsub(/_/, '-')), desc if short_desc && desc
    #         pc.long_desc long_desc if long_desc
    #         pc.dup_method an.to_sym, cn.to_sym
    #       } if aliases
    #     end
    #   }
    # end
    #
    # def add_debugging(base, option_sym, env_sym)
    #   methods = base.commands.keys - base.subcommands
    #   base.class_eval {
    #     methods.each { |method_name|
    #       original_method = instance_method(method_name)
    #       no_commands {
    #         define_method(method_name) { |*args, &block|
    #           debug = if option_sym && (options.has_key?(option_sym.to_s) || options.has_key?(option_sym.to_sym))
    #                     options[option_sym.to_sym]
    #                   elsif env_sym
    #                     d = ENV[env_sym.to_s]
    #                     d == '1' || d == 1 || d == 'true' || d == 't'
    #                   end
    #           if debug
    #             puts "command: #{self.class.basename2} #{__method__.gsub(/_/, '-').to_s}"
    #             puts "parent_options: #{parent_options.inspect}"
    #             puts "options: #{options.inspect}"
    #             original_method.parameters.each_with_index { |p, i| puts "#{p[1].to_s}: #{args[i]}" }
    #           end
    #           begin
    #             original_method.bind(self).call(*args, &block)
    #           rescue ArgumentError => e
    #             base.handle_argument_error(base.commands[method_name], e, args, original_method.arity)
    #           end
    #         }
    #       }
    #     }
    #   }
    #   base.subcommand_classes.values.each { |c| add_debugging(c, option_sym, env_sym) }
    # end
    #
    # private :build_recurse
  end
end