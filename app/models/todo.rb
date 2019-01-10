class Todo
  include Dynamoid::Document

  table name: "#{ENV[:DYNAMO_PREFIX]}-todos", key: :id
  field :text, :string
end
