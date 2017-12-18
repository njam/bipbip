require 'bipbip'
require 'bipbip/plugin/redis'

describe Bipbip::Plugin::Redis do
  let(:plugin) { Bipbip::Plugin::Redis.new('redis', { 'hostname' => 'redis', 'port' => 6379 }, 10) }

  it 'should collect data' do
    data = plugin.monitor

    data['total_commands_processed'].should be_kind_of(Integer)
    data['used_memory'].should be_kind_of(Integer)
    data['mem_fragmentation_ratio'].should be_instance_of(Float)
  end
end
