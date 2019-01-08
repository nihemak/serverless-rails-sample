class TodosController < ApplicationController
  before_action :set_todos
  before_action :set_todo, only: [:show, :update]

  # GET /todos
  def index
    render json: @todos, status: :ok
  end

  # POST /todos
  def create
    @todo = {
      id: SecureRandom.uuid,
      text: todo_params[:text]
    }
    @todos.push(@todo)
    render json: @todo, status: :created
  end

  # GET /todos/:id
  def show
    render json: @todo, status: :ok
  end

  # PUT /todos/:id
  def update
    @todo[:text] = todo_params[:text]
    head :no_content
  end

  # DELETE /todos/:id
  def destroy
    @todos.reject! {|t| t[:id] == params[:id]}
    head :no_content
  end

  private

  def set_todos
    @todos = [
      {
        id: "bc55004d-6bf3-45ba-a785-a2c2b62b24d8",
        text: "test todo1"
      },
      {
        id: "458b67c1-9263-4827-b0bf-6cf406a38c70",
        text: "test todo2"
      }
    ]
  end

  def set_todo
    @todo = @todos.find { |t| t[:id] == params[:id] }
  end

  def todo_params
    params.permit(:text)
  end
end
