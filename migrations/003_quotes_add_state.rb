# encoding: UTF-8

Sequel.migration do
  up do
    add_column :quotes, :state, String, default: 'pending'
    from(:quotes).update(:state => 'pending')
  end

  down do
    drop_column :quotes, :state
  end
end
