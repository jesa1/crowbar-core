module ServiceRestart
  class RestartManager
    def initialize(cookbook_name, node, new_resource, is_pacemaker_service)
      @cookbook_name = cookbook_name
      @node = node
      @service_name = new_resource.name.to_sym
      @is_pacemaker_service = is_pacemaker_service
    end

    def cookbook
      # if the cookbook_name is apache2, then any cookbook could have triggered it, so
      # try to pick the value from the extra key that we set
      if @cookbook_name == "apache2"
        @node.run_state["apache2_restart_origin"]
      else
        @cookbook_name.to_s
      end
    end

    def add_restart_management_node_attributes
      @node.set[:crowbar_wall] = {} unless @node[:crowbar_wall]
      @node.set[:crowbar_wall][:requires_restart] = {} \
            unless @node[:crowbar_wall][:requires_restart]
      @node.set[:crowbar_wall][:requires_restart][cookbook] = {} \
            unless @node[:crowbar_wall][:requires_restart][cookbook]
    end

    def disallow_restart?
      # if the databag or item does not exits it returns a 404
      data_bag = Chef::DataBagItem.load("crowbar-config", "disallow_restart") rescue {}

      data_bag[cookbook] || false
    end

    def register_restart_request
      # Store more data about the service attempted restart
      # use the service as the key name for the data for easy removal
      # we have to force the attributes to be a simple hash instead of a node attribute if you want
      # the update method to actually update. If you update the attribute directly it doesn't
      # update but overwrites! The joys of chef!
      add_restart_management_node_attributes
      requires_restart_hash = @node[:crowbar_wall][:requires_restart][cookbook].to_h
      @node.set[:crowbar_wall][:requires_restart][cookbook] = requires_restart_hash.update(
        @service_name => {
          pacemaker_service: @is_pacemaker_service,
          timestamp: Time.now.getutc
        }
      )
    end

    def clear_restart_requests
      @node.fetch(
        :crowbar_wall, {}
      ).fetch(
        :requires_restart, {}
      ).fetch(
        cookbook, {}
      ).delete(@service_name)
    end
  end
end
