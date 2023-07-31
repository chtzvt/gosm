# frozen_string_literal: true

# As of Octokit v7.0 (3ada8e8f30db61dca52a4c3f0f53cce4f71293be), the library lacks
# inbuilt support for the Organization secrets API.

# This implementation is more or less a copy of the existing Actions secrets API module:
# https://github.com/octokit/octokit.rb/blob/8a6325427dc3ad234b8ff8242f73c390aa8120e6/lib/octokit/client/actions_secrets.rb

# I'll be opening a PR to bring this functionality upstream Soon(tm)

module Octokit
  class Client
    # Methods for the Organization Secrets API
    #
    # @see https://docs.github.com/en/rest/actions/secrets?apiVersion=2022-11-28
    module OrganizationSecrets
      # Get organization public key for secrets encryption
      #
      # @param org [Integer, String, Hash, Organization] A GitHub organization
      # @return [Hash] key_id and key
      # @see https://docs.github.com/en/rest/actions/secrets?apiVersion=2022-11-28#get-an-organization-public-key
      def get_org_public_key(org)
        get "#{Organization.path org}/actions/secrets/public-key"
      end

      # List organization secrets
      #
      # @param org [Integer, String, Hash, Organization] A GitHub organization
      # @return [Hash] total_count and list of secrets (each item is hash with name, created_at and updated_at)
      # @see https://docs.github.com/en/rest/actions/secrets?apiVersion=2022-11-28#list-repository-organization-secrets
      def list_org_secrets(org)
        paginate "#{Organization.path org}/actions/secrets" do |data, last_response|
          data.secrets.concat last_response.data.secrets
        end
      end

      # Get an organization secret
      #
      # @param org [Integer, String, Hash, Organization] A GitHub organization
      # @param name [String] Name of secret
      # @return [Hash] name, created_at and updated_at
      # @see https://docs.github.com/en/rest/actions/secrets?apiVersion=2022-11-28#get-an-organization-secret
      def get_org_secret(org, name)
        get "#{Organization.path org}/actions/secrets/#{name}"
      end

      # Create or update organization secrets
      #
      # @param org [Integer, String, Hash, Organization] A GitHub organization
      # @param name [String] Name of secret
      # @param options [Hash] encrypted_value and key_id
      # @see https://docs.github.com/en/rest/actions/secrets?apiVersion=2022-11-28#create-or-update-an-organization-secret
      def create_or_update_org_secret(org, name, options)
        put "#{Organization.path org}/actions/secrets/#{name}", options
      end

      # Delete an organization secret
      #
      # @param org [Integer, String, Hash, Organization] A GitHub organization
      # @param name [String] Name of secret
      # @see https://docs.github.com/en/rest/actions/secrets?apiVersion=2022-11-28#delete-an-organization-secret
      def delete_org_secret(org, name)
        boolean_from_response :delete, "#{Organization.path org}/actions/secrets/#{name}"
      end
    end

    include Octokit::Client::OrganizationSecrets
  end
end
