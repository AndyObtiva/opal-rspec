class ::RSpec::Core::Example  
  def notify_async_completed(reporter, exception=nil)
    puts "notify_async_completed called with exception #{exception}"
    Promise.value(nil).then do
      Promise.value(nil).then do
        if exception
          unless exception.is_a? Pending::SkipDeclaredInExample
            puts 'got an exception, noting it'
            # exception needs to be set before calling finish so results are correct
            # the first test to fail should be the one reported
            set_exception exception
          end            
        else
          if pending?
            puts 'found pending example that did not fail!!!'
            ::RSpec::Core::Pending.mark_fixed! self

            set_exception ::RSpec::Core::Pending::PendingExampleFixedError.new(
                  'Expected example to fail since it is pending, but it passed.',
                  [location])
          end        
        end
      end.ensure do
        run_after_example
      end
    end.rescue do |e|
      set_exception e
    end.ensure do
      @example_group_instance.instance_variables.each do |ivar|
        @example_group_instance.instance_variable_set(ivar, nil)
      end  
      @example_group_instance = nil
      
      result = finish(reporter)     
      puts "----- example complete #{metadata[:description]} with result #{result} ------"
      ::RSpec.current_example = nil
      result
    end     
  end
  
  def core_block_run(reporter)
    possible_example_promise = @example_group_instance.instance_exec(self, &@example_block)    
    puts "possible_example_promise for #{metadata[:description]} is a #{possible_example_promise}"
    synchronous_example = !possible_example_promise.is_a?(Promise)
    puts "synchronous example!" if synchronous_example
    example_promise = synchronous_example ? Promise.value(possible_example_promise) : possible_example_promise
    example_promise.then do |result|
      puts 'notifying completed'
      notify_async_completed reporter      
    end.rescue do |ex|
      ex ||= Exception.new 'Async promise failed for unspecified reason'
      ex = Exception.new ex unless ex.kind_of?(Exception)          
      puts "notifying example exception #{ex}"
      notify_async_completed reporter, ex      
    end
  end
  
  def resolve_subject
    if example_group_instance.respond_to? :subject and example_group_instance.subject.is_a?(Promise)
      example_group_instance.subject.then do |resolved_subject|
        # This is a private method, but we're using Opal
        example_group_instance.__memoized[:subject] = resolved_subject        
      end
    else
      Promise.value
    end
  end
  
  def run(example_group_instance, reporter)
    puts "----- example begin #{metadata[:description]} ------"    
    @example_group_instance = example_group_instance
    ::RSpec.current_example = self

    start(reporter)
    ::RSpec::Core::Pending.mark_pending!(self, pending) if pending?    

    if skipped?
      ::RSpec::Core::Pending.mark_pending! self, skip
      result = finish(reporter)              
      ::RSpec.current_example = nil
      return Promise.value result
    elsif !::RSpec.configuration.dry_run?
      # TODO: Put around back in here      
      begin
        run_before_example.then do
          resolve_subject         
        end.then do
          core_block_run reporter          
        end.fail do |ex|
          notify_async_completed(reporter, ex)
        end        
      rescue Exception => ex
        puts "Synchronous exception detected! #{ex}"
        notify_async_completed(reporter, ex)
      end
    end
  end
end
