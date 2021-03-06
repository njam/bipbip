require 'bipbip'
require 'bipbip/plugin/mongodb'

describe Bipbip::Plugin::Mongodb do
  let(:plugin) { Bipbip::Plugin::Mongodb.new('mongodb', { 'hostname' => 'localhost', 'port' => 27_017 }, 10) }

  it 'should collect data' do
    allow(plugin).to receive(:fetch_server_status).and_return(
      'connections' => {
        'current' => 100
      },
      'mem' => {
        'resident' => 1024
      }
    )

    allow(plugin).to receive(:total_index_size).and_return(50 * 1024 * 1024)
    allow(plugin).to receive(:total_system_memory).and_return(200 * 1024 * 1024)

    data = plugin.monitor
    data['replication_lag'].should eq(nil)
    data['slow_queries_count'].should eq(nil)
    data['connections_current'].should eq(100)
    data['mem_resident'].should eq(1024)
    data['total_index_size'].should eq(50)
    data['total_index_size_percentage_of_memory'].should eq(25)
  end

  it 'should collect replication lag' do
    allow(plugin).to receive(:fetch_server_status).and_return(
      'repl' => {
        'secondary' => true
      }
    )

    allow(plugin).to receive(:fetch_replica_status).and_return(
      'set' => 'rep1',
      'members' => [
        { 'stateStr' => 'PRIMARY', 'optime' => BSON::Timestamp.new(1000, 1) },
        { 'stateStr' => 'SECONDARY', 'optime' => BSON::Timestamp.new(1003, 1), 'self' => true }
      ]
    )

    allow(plugin).to receive(:total_index_size).and_return(50 * 1024 * 1024)
    allow(plugin).to receive(:total_system_memory).and_return(200 * 1024 * 1024)

    data = plugin.monitor
    data['replication_lag'].should eq(3)
    data['slow_queries_count'].should eq(nil)
  end

  it 'should collect slow queries' do
    allow(plugin).to receive(:fetch_server_status).and_return(
      'repl' => {
        'ismaster' => true
      }
    )

    allow(plugin).to receive(:fetch_replica_status).and_return(
      'set' => 'rep1',
      'members' => [
        { 'stateStr' => 'PRIMARY', 'optime' => BSON::Timestamp.new(1000, 1) },
        { 'stateStr' => 'SECONDARY', 'optime' => BSON::Timestamp.new(1003, 1), 'self' => true }
      ]
    )

    allow(plugin).to receive(:fetch_slow_queries_status).and_return(
      'total' => {
        'count' => 48.4,
        'time' => 24.2
      },
      'max' => {
        'time' => 12
      }
    )

    allow(plugin).to receive(:total_index_size).and_return(50 * 1024 * 1024)
    allow(plugin).to receive(:total_system_memory).and_return(200 * 1024 * 1024)

    data = plugin.monitor
    data['replication_lag'].should eq(nil)
    data['slow_queries_count'].should eq(48.4)
    data['slow_queries_time_avg'].should eq(0.5)
    data['slow_queries_time_max'].should eq(12)
  end
end
