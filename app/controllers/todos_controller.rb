class TodosController < ApplicationController
  # GET /todos
  def index
    todos = [
      {
        "id": "bc55004d-6bf3-45ba-a785-a2c2b62b24d8",
        "text": "test todo1",
        "checked": false
      },
      {
        "id": "458b67c1-9263-4827-b0bf-6cf406a38c70",
        "text": "test todo2",
        "checked": true
      }
    ]
    render json: todos
  end
end
