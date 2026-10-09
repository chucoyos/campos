class UsersController < ApplicationController
  before_action :set_user, only: %i[show edit update destroy]

  def index
    authorize User
    @users = policy_scope(User).order(:email)
  end

  def show
  end

  def new
    @user = User.new
    authorize @user
  end

  def create
    @user = User.new(user_params)
    authorize @user

    if @user.save
      redirect_to users_path, notice: t("flash.users.create")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    attrs = user_params
    attrs = attrs.except(:password, :password_confirmation) if attrs[:password].blank?

    if @user.update(attrs)
      redirect_to users_path, notice: t("flash.users.update")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @user.destroy
    redirect_to users_path, notice: t("flash.users.destroy")
  end

  private

  def set_user
    @user = User.find(params[:id])
    authorize @user
  end

  def user_params
    params.expect(user: %i[email role password password_confirmation])
  end
end
