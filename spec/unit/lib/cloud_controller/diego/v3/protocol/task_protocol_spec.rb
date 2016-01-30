require 'spec_helper'
require_relative '../../lifecycle_protocol_shared'
require_relative '../../../../../../../lib/cloud_controller/diego/v3/protocol/task_protocol'

module VCAP::CloudController
  module Diego
    module V3
      module Protocol
        describe TaskProtocol do
          let(:default_health_check_timeout) { 99 }
          let(:egress_rules) { double(:egress_rules) }

          subject(:protocol) do
            TaskProtocol.new(egress_rules)
          end

          before do
            allow(egress_rules).to receive(:staging).and_return(['staging_egress_rule'])
            allow(egress_rules).to receive(:running).with(app).and_return(['running_egress_rule'])
          end

          describe '#task_request' do
            let(:user) { 'user' }
            let(:password) { 'password' }
            let(:internal_service_hostname) { 'internal_service_hostname' }
            let(:external_port) { 8080 }
            let(:config) do
              {
                internal_api:              {
                  auth_user:     user,
                  auth_password: password,
                },
                internal_service_hostname: internal_service_hostname,
                external_port:             external_port,
                default_app_disk_in_mb:    1024,
              }
            end

            let(:local_dir) { Dir.mktmpdir }
            let!(:blobstore) { CloudController::Blobstore::Client.new({ provider: 'Local', local_root: local_dir }, 'directory_key') }

            before do
              allow(CloudController::DependencyLocator.instance).to receive(:blobstore_url_generator).and_return(blobstore)
              allow(blobstore).to receive(:v3_droplet_download_url).and_return('www.droplet.url')
            end

            let(:memory_in_mb) { 2048 }
            let(:task) { TaskModel.make(app_guid: app.guid, droplet_guid: droplet.guid, command: 'be rake my panda', memory_in_mb: memory_in_mb) }

            context 'the task has a buildpack droplet' do
              let(:app) { AppModel.make }
              let(:droplet) { DropletModel.make(:buildpack, app_guid: app.guid, environment_variables: { 'foo' => 'bar' }) }

              before do
                app.buildpack_lifecycle_data = BuildpackLifecycleDataModel.make
                app.save
              end

              it 'contains the correct payload for creating a task' do
                result = protocol.task_request(task, config)

                expect(JSON.parse(result)).to eq({
                  'task_guid' => task.guid,
                  'rootfs' => app.lifecycle_data.stack,
                  'log_guid' => app.guid,
                  'environment' => [{ 'name' => 'foo', 'value' => 'bar' }],
                  'memory_mb' => memory_in_mb,
                  'disk_mb' => 1024,
                  'egress_rules' => ['running_egress_rule'],
                  'droplet_uri' => 'www.droplet.url',
                  'lifecycle' => Lifecycles::BUILDPACK,
                  'command' => 'be rake my panda',
                  'completion_callback' => "http://#{user}:#{password}@#{internal_service_hostname}:#{external_port}/internal/v3/tasks/#{task.guid}/completed"
                })
              end
            end

            context 'the task has a docker file droplet' do
              let(:app) { AppModel.make }
              let(:droplet) { DropletModel.make(:docker, app_guid: app.guid, environment_variables: { 'foo' => 'bar' }, docker_receipt_image: 'cloudfoundry/capi-docker') }

              it 'contains the correct payload for creating a task' do
                result = protocol.task_request(task, config)

                expect(JSON.parse(result)).to eq({
                  'task_guid' => task.guid,
                  'log_guid' => app.guid,
                  'environment' => [{ 'name' => 'foo', 'value' => 'bar' }],
                  'memory_mb' => memory_in_mb,
                  'disk_mb' => 1024,
                  'egress_rules' => ['running_egress_rule'],
                  'docker_path' => 'cloudfoundry/capi-docker',
                  'lifecycle' => Lifecycles::DOCKER,
                  'command' => 'be rake my panda',
                  'completion_callback' => "http://#{user}:#{password}@#{internal_service_hostname}:#{external_port}/internal/v3/tasks/#{task.guid}/completed"
                })
              end
            end
          end
        end
      end
    end
  end
end
