# encoding: UTF-8
Sequel.migration do
  up do
    unless DB.table_exists?(:quotes)
      create_table(:quotes) do
        primary_key :id
        String :topic
        String :body, null: false
      end
    end
  end

  down do
    drop_table(:quotes)
  end
end
