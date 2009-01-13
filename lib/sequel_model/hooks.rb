module Sequel
  class Model
    # Hooks that are safe for public use
    HOOKS = [:after_initialize, :before_create, :after_create, :before_update,
      :after_update, :before_save, :after_save, :before_destroy, :after_destroy,
      :before_validation, :after_validation]

    # Hooks that are only for internal use
    PRIVATE_HOOKS = [:before_update_values, :before_delete]
    
    # Returns true if there are any hook blocks for the given hook.
    def self.has_hooks?(hook)
      !@hooks[hook].empty?
    end

    # Yield every block related to the given hook.
    def self.hook_blocks(hook)
      @hooks[hook].each{|k,v| yield v}
    end

    ### Private Class Methods ###

    # Add a hook block to the list of hook methods.
    # If a non-nil tag is given and it already is in the list of hooks,
    # replace it with the new block.
    def self.add_hook(hook, tag, &block) #:nodoc:
      unless block
        (raise Error, 'No hook method specified') unless tag
        block = proc {send tag}
      end
      h = @hooks[hook]
      if tag && (old = h.find{|x| x[0] == tag})
        old[1] = block
      else
        h << [tag, block]
      end
    end

    # This method allows to define own hook method for model
    #
    # class MyModel
    #   define_hook :before_move_to
    #   before_move_to { STDERR.puts "I'm in before move_to method"
    #   def move_to
    #     if before_move_to
    #       STDERR.puts "before_move_to hook returned true so i can move on"
    #     else
    #       STDERR.puts "before_move_to hook returned false so i should stop now"
    #       return
    #     end
    #     # Some other code of move_to method
    #   end
    # end
    #
    # It's better to use this method internally, in plugins to keep code of your model clean.
    def self.define_hook(hook)
      @hooks[hook] = []
      instance_eval("def #{hook}(method = nil, &block); define_hook_instance_method(:#{hook}); add_hook(:#{hook}, method, &block) end")
      class_eval("def #{hook}; end")
    end

    # Define a hook instance method that calls the run_hooks instance method.
    def self.define_hook_instance_method(hook) #:nodoc:
      class_eval("def #{hook}; run_hooks(:#{hook}); end")
    end

    private_class_method :add_hook, :define_hook_instance_method

    private

    # Runs all hook blocks of given hook type on this object.
    # Stops running hook blocks and returns false if any hook block returns false.
    def run_hooks(hook)
      model.hook_blocks(hook){|block| return false if instance_eval(&block) == false}
    end
    
    # For performance reasons, we define empty hook instance methods, which are
    # overwritten with real hook instance methods whenever the hook class method is called.
    (HOOKS + PRIVATE_HOOKS).each do |hook|
      define_hook(hook)
    end
  end
end
