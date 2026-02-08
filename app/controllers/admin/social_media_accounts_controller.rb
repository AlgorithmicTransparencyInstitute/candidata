module Admin
  class SocialMediaAccountsController < Admin::BaseController
    def index
      @accounts = SocialMediaAccount.includes(:person, :entered_by, :verified_by)
                                    .order(created_at: :desc)

      # Search by URL or Handle
      if params[:search].present?
        search_term = "%#{params[:search]}%"
        @accounts = @accounts.where("url ILIKE ? OR handle ILIKE ?", search_term, search_term)
      end

      # Filter by person name
      if params[:person_name].present?
        search_term = "%#{params[:person_name].downcase}%"
        @accounts = @accounts.joins(:person)
                            .where("LOWER(people.first_name) LIKE :term OR LOWER(people.last_name) LIKE :term", term: search_term)
      end

      # Filter by state
      if params[:state].present?
        @accounts = @accounts.joins(:person).where(people: { state_of_residence: params[:state] })
      end

      # Filter by party
      if params[:party_id].present?
        @accounts = @accounts.joins(person: :person_parties)
                            .where(person_parties: { party_id: params[:party_id], is_primary: true })
      end

      # Filter by platform
      if params[:platform].present?
        @accounts = @accounts.where(platform: params[:platform])
      end

      # Filter by research status
      if params[:research_status].present?
        @accounts = @accounts.where(research_status: params[:research_status])
      end

      # Filter by channel type
      if params[:channel_type].present?
        @accounts = @accounts.where(channel_type: params[:channel_type])
      end

      # Filter by account status
      case params[:account_status]
      when 'active'
        @accounts = @accounts.active
      when 'inactive'
        @accounts = @accounts.inactive
      end

      @accounts = @accounts.page(params[:page]).per(50)

      # For filter dropdowns
      @states = Person.where.not(state_of_residence: [nil, '']).distinct.pluck(:state_of_residence).sort
      @parties = Party.all.sort_by do |party|
        case party.name
        when 'Republican' then [0, party.name]
        when 'Democratic' then [1, party.name]
        else [2, party.name]
        end
      end
      @platforms = SocialMediaAccount::PLATFORMS
      @research_statuses = SocialMediaAccount::RESEARCH_STATUSES
      @channel_types = SocialMediaAccount::CHANNEL_TYPES
    end

    def show
      @account = SocialMediaAccount.find(params[:id])
      @person = @account.person
    end

    def new
      @account = SocialMediaAccount.new
      @people = Person.order(:last_name, :first_name).limit(1000)
      @platforms = SocialMediaAccount::PLATFORMS
      @channel_types = SocialMediaAccount::CHANNEL_TYPES
    end

    def create
      @account = SocialMediaAccount.new(account_params)

      if @account.save
        redirect_to admin_social_media_account_path(@account), notice: "Social media account created."
      else
        @people = Person.order(:last_name, :first_name).limit(1000)
        @platforms = SocialMediaAccount::PLATFORMS
        @channel_types = SocialMediaAccount::CHANNEL_TYPES
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @account = SocialMediaAccount.find(params[:id])
      @people = Person.order(:last_name, :first_name).limit(1000)
      @platforms = SocialMediaAccount::PLATFORMS
      @channel_types = SocialMediaAccount::CHANNEL_TYPES
    end

    def update
      @account = SocialMediaAccount.find(params[:id])

      if @account.update(account_params)
        redirect_to admin_social_media_account_path(@account), notice: "Social media account updated."
      else
        @people = Person.order(:last_name, :first_name).limit(1000)
        @platforms = SocialMediaAccount::PLATFORMS
        @channel_types = SocialMediaAccount::CHANNEL_TYPES
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @account = SocialMediaAccount.find(params[:id])
      @account.destroy
      redirect_to admin_social_media_accounts_path, notice: "Social media account deleted."
    end

    private

    def account_params
      params.require(:social_media_account).permit(
        :person_id, :platform, :url, :handle, :channel_type, :research_status,
        :account_inactive, :research_notes, :verification_notes, :pre_populated
      )
    end
  end
end
