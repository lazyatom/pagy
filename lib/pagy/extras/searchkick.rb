# See the Pagy documentation: https://ddnexus.github.io/pagy/extras/searchkick
# encoding: utf-8
# frozen_string_literal: true

class Pagy

  module Searchkick
    # returns an array used to delay the call of #search
    # after the pagination variables are merged to the options
    # it also pushes to the same array an eventually called method and arguments
    def pagy_search(term = "*", **options, &block)
      [self, term, options, block].tap do |args|
        args.define_singleton_method(:method_missing){|*a| args += a}
      end
    end
  end

  # create a Pagy object from a Searchkick::Results object
  def self.new_from_searchkick(results, vars={})
    vars[:items] = results.options[:per_page]
    vars[:page]  = results.options[:page]
    vars[:count] = results.total_count
    new(vars)
  end

  # Add specialized backend methods to paginate Searchkick::Results
  module Backend ; private

    # Return Pagy object and results
    def pagy_searchkick(pagy_search_args, vars={})
      model, term, options, block, *called = pagy_search_args
      vars               = pagy_searchkick_get_vars(nil, vars)
      options[:per_page] = vars[:items]
      options[:page]     = vars[:page]
      results            = model.search(term, **options, &block)
      vars[:count]       = results.total_count
      pagy = Pagy.new(vars)
      # with :last_page overflow we need to re-run the method in order to get the hits
      if defined?(Pagy::Overflow) && pagy.overflow? && pagy.vars[:overflow] == :last_page
        return pagy_searchkick(pagy_search_args, vars.merge(page: pagy.page))
      end
      return pagy, called.empty? ? results : results.send(*called)
    end

    # Sub-method called only by #pagy_searchkick: here for easy customization of variables by overriding
    # the _collection argument is not available when the method is called
    def pagy_searchkick_get_vars(_collection, vars)
      vars[:items] ||= VARS[:items]
      vars[:page]  ||= (params[ vars[:page_param] || VARS[:page_param] ] || 1).to_i
      vars
    end

  end
end
