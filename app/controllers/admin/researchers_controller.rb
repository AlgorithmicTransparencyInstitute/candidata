module Admin
  class ResearchersController < Admin::BaseController
    def index
      @researchers = User.where(role: 'researcher')
                         .includes(:assignments)

      # Apply search
      if params[:search].present?
        search_term = "%#{params[:search]}%"
        @researchers = @researchers.where("name ILIKE ? OR email ILIKE ?", search_term, search_term)
      end

      # Apply filters
      if params[:filter].present?
        case params[:filter]
        when 'has_pending_collection'
          @researchers = @researchers.joins(:assignments).where(assignments: { status: 'pending', task_type: 'data_collection' }).distinct
        when 'has_pending_validation'
          @researchers = @researchers.joins(:assignments).where(assignments: { status: 'pending', task_type: 'data_validation' }).distinct
        when 'has_any_pending'
          @researchers = @researchers.joins(:assignments).where(assignments: { status: 'pending' }).distinct
        when 'has_in_progress'
          @researchers = @researchers.joins(:assignments).where(assignments: { status: 'in_progress' }).distinct
        when 'no_assignments'
          @researchers = @researchers.left_joins(:assignments).where(assignments: { id: nil })
        end
      end

      # Precompute assignment counts for each researcher
      all_researchers = @researchers.to_a
      all_researchers.each do |researcher|
        assignments = researcher.assignments

        # Data collection counts
        collection_assignments = assignments.select { |a| a.task_type == 'data_collection' }
        researcher.instance_variable_set(:@collection_pending, collection_assignments.count { |a| a.status == 'pending' })
        researcher.instance_variable_set(:@collection_in_progress, collection_assignments.count { |a| a.status == 'in_progress' })
        researcher.instance_variable_set(:@collection_completed, collection_assignments.count { |a| a.status == 'completed' })

        # Data validation counts
        validation_assignments = assignments.select { |a| a.task_type == 'data_validation' }
        researcher.instance_variable_set(:@validation_pending, validation_assignments.count { |a| a.status == 'pending' })
        researcher.instance_variable_set(:@validation_in_progress, validation_assignments.count { |a| a.status == 'in_progress' })
        researcher.instance_variable_set(:@validation_completed, validation_assignments.count { |a| a.status == 'completed' })

        # Total counts
        researcher.instance_variable_set(:@total_pending, assignments.count { |a| a.status == 'pending' })
        researcher.instance_variable_set(:@total_in_progress, assignments.count { |a| a.status == 'in_progress' })
        researcher.instance_variable_set(:@total_completed, assignments.count { |a| a.status == 'completed' })
        researcher.instance_variable_set(:@total_assignments, assignments.count)
      end

      # Apply sorting
      case params[:sort]
      when 'pending_desc'
        all_researchers.sort_by! { |r| -r.instance_variable_get(:@total_pending) }
      when 'in_progress_desc'
        all_researchers.sort_by! { |r| -r.instance_variable_get(:@total_in_progress) }
      when 'completed_desc'
        all_researchers.sort_by! { |r| -r.instance_variable_get(:@total_completed) }
      when 'total_desc'
        all_researchers.sort_by! { |r| -r.instance_variable_get(:@total_assignments) }
      else
        all_researchers.sort_by! { |r| r.name || r.email }
      end

      @researchers = Kaminari.paginate_array(all_researchers).page(params[:page]).per(50)
    end
  end
end
