module RedmineGitHosting
  module GitoliteWrappers
    class Repositories < Admin


      def initialize(*args)
        super

        # Find object or raise error
        # find_repository
      end


      def add_repository
        if repository = Repository.find_by_id(object_id)
          admin.transaction do
            RedmineGitHosting::GitoliteHandlers::RepositoryAdder.new(repository, gitolite_config, action, options).call
            gitolite_admin_repo_commit("#{repository.gitolite_repository_name}")
            recycle = RedmineGitHosting::Recycle.new
            @recovered = recycle.recover_repository_if_present?(repository)

            if !@recovered
              logger.info("#{action} : let Gitolite create empty repository '#{repository.gitolite_repository_path}'")
            else
              logger.info("#{action} : restored existing Gitolite repository '#{repository.gitolite_repository_path}' for update")
            end
          end

          # Call Gitolite plugins
          execute_post_create_actions(repository, @recovered)

          # Fetch changeset
          repository.fetch_changesets
        else
          logger.error("#{action} : repository does not exist anymore, object is nil, exit !")
        end
      end


      def update_repository
        if repository = Repository.find_by_id(object_id)
          admin.transaction do
            RedmineGitHosting::GitoliteHandlers::RepositoryUpdater.new(repository, gitolite_config, action, options).call
            gitolite_admin_repo_commit("#{repository.gitolite_repository_name}")
          end

          # Call Gitolite plugins
          execute_post_update_actions(repository)

          # Fetch changeset
          repository.fetch_changesets
        else
          logger.error("#{action} : repository does not exist anymore, object is nil, exit !")
        end
      end


      def delete_repository
        repository_data = object_id
        admin.transaction do
          RedmineGitHosting::GitoliteHandlers::RepositoryDeleter.new(repository_data, gitolite_config, action).call
          gitolite_admin_repo_commit("#{repository_data['repo_name']}")
        end

        # Call Gitolite plugins
        execute_post_delete_actions(repository_data)
      end


      def delete_repositories
        admin.transaction do
          object_id.each do |repository_data|
            RedmineGitHosting::GitoliteHandlers::RepositoryDeleter.new(repository_data, gitolite_config, action).call
            gitolite_admin_repo_commit("#{repository_data['repo_name']}")
          end
        end

        # Call Gitolite plugins
        execute_post_delete_actions(repository_data)
      end


      def update_repository_default_branch
        if repository = Repository.find_by_id(object_id)
          RedmineGitHosting::GitoliteHandlers::RepositoryBranchUpdater.new(repository).call
        else
          logger.error("#{action} : repository does not exist anymore, object is nil, exit !")
        end
      end


      private


        def execute_post_create_actions(repository, recovered = false)
          # Create README file or initialize GitAnnex
          RedmineGitHosting::Plugins.execute(:post_create, repository, options.merge(recovered: recovered))
        end


        def execute_post_update_actions(repository)
          # Delete Git Config Keys
          RedmineGitHosting::Plugins.execute(:post_update, repository, options)
        end


        def execute_post_delete_actions(repository_data)
          # Move repository to RecycleBin
          RedmineGitHosting::Plugins.execute(:post_delete, repository_data)
        end

    end
  end
end
