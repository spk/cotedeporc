# encoding: UTF-8

Sequel.migration do
  up do
    add_column :quotes, :created_at, Time
    from(:quotes).update(:created_at => Time.now)
  end

  down do
    drop_column :quotes, :created_at
  end
end
