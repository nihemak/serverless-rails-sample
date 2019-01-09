class Todo
  include Dynamoid::Document

  table name: :todos, key: :id
  field :text, :string
end
