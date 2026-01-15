class HomeController < ApplicationController
  def index
    if session[:user_email]
      @user_email = session[:user_email]
    else
      redirect_to login_path
    end
  end

  def login
    redirect_to root_path if session[:user_email]
  end

  def authenticate
    email = params[:email]
    password = params[:password]

    # TODO: Validate credentials against Airtable
    # For now, just store the email in session for development
    if email.present? && password.present?
      session[:user_email] = email
      flash[:notice] = "Successfully logged in!"
      redirect_to root_path
    else
      flash.now[:alert] = "Please enter both email and password"
      render :login, status: :unprocessable_entity
    end
  end

  def logout
    session[:user_email] = nil
    flash[:notice] = "You have been logged out"
    redirect_to login_path
  end
end
