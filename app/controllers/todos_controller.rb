class TodosController < ApplicationController
  before_action :set_todo, only: [:show, :update, :destroy]

  # GET /todos
  def index
    @todos = Todo.all
    render json: @todos, status: :ok
  end

  # POST /todos
  def create
    @todo = Todo.new
    @todo.text = todo_params[:text]
    @todo.save
  end

  # GET /todos/:id
  def show
    render json: @todo, status: :ok
  end

  # PUT /todos/:id
  def update
    @todo.text = todo_params[:text]
    @todo.save
    head :no_content
  end

  # DELETE /todos/:id
  def destroy
    @todo.delete
    head :no_content
  end

  private

  def set_todo
    @todo = Todo.find params[:id]
  end

  def todo_params
    params.permit(:text)
  end
end
