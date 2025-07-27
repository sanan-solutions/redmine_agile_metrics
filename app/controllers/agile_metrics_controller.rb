class AgileMetricsController < ApplicationController
  before_action :find_project
  before_action :current_version
  skip_before_action :check_if_login_required
  # before_action :authorize  

  def index
    Rails.logger.info ">>> User1: #{User.current.login}"
    # Status By Tracker Pie Chart
    # Danh sách sprint của project (mặc định sắp theo ngày)
    @versions = Version.where(project_id: @project.id)
    .sort_by { |v| v.effective_date || Date.new(0) }
    .reverse

    # Sprint đang được chọn để filter pie chart (nếu có)
    @selected_version_id = params[:version_id] || @versions.first&.id
    @selected_version = Version.find_by(id: @selected_version_id)

    # Biểu đồ pie – trạng thái issue theo sprint được chọn
    @issue_status_data = if @selected_version
      Issue.where(project_id: @project.id, fixed_version_id: @selected_version.id)
          .group(:status_id)
          .count
          .map { |status_id, count| { name: IssueStatus.find(status_id).name, count: count } }
    else
      []
    end

    # Count Bug By priority
    # Bug count by Priority
    @bug_priority_data = Issue.where(tracker: Tracker.find_by(name: 'Bug'), project: @project)
    .group(:priority_id)
    .count

    @bug_priority_labels = IssuePriority.where(id: @bug_priority_data.keys).map do |p|
    count = @bug_priority_data[p.id] || 0
    "#{p.name} (#{count})"
    end

    @bug_priority_counts = @bug_priority_labels.map do |label|
    label.match(/\((\d+)\)/)[1].to_i
    end
  end

  def get_velocity_chart_data
    Rails.logger.info "Cookies = #{cookies.to_hash.inspect}"
    Rails.logger.info ">>> Session keys: #{session.to_hash.keys}"
    Rails.logger.info ">>> Current user: #{User.current.inspect}"
    Rails.logger.info ">>> User: #{User.current.login}"
    # Velocity Chart
    @versions = @project.shared_versions.sorted
    velocity_data = @versions.map do |version|
      fixed_issues = version.fixed_issues.includes(:agile_data, :status, :tracker)

      completed = fixed_issues.select(&:closed?).map(&:story_points).compact.sum
      total     = fixed_issues.map(&:story_points).compact.sum
      bug_count = fixed_issues.select { |i| i.tracker&.name == 'Bug' }.count

      {
        version: version.name,
        completed: completed,
        total: total,
        bug_count: bug_count
      }
    end

    render json: velocity_data
  end

  def get_issue_status_pie_data
    # Pie chart: Issue status by selected version
    issue_status_data = if @current_version
      Issue.where(project_id: @project.id, fixed_version_id: @current_version.id)
           .group(:status_id)
           .count
           .map do |status_id, count|
              {
                name: IssueStatus.find_by(id: status_id)&.name || "Unknown",
                count: count
              }
           end
    else
      []
    end

    render json: issue_status_data
  end

  def get_burndown_chart_data
    @issues = @current_version.fixed_issues
    options = { 
      date_from: @current_version.start_date,
      date_to: @current_version.due_date,
      due_date: @current_version.due_date,
      chart_unit: params[:chart_unit] 
    }
    @chart = "burndown_chart"

    agile_chart = RedmineAgile::Charts::Helper::AGILE_CHARTS[@chart]
    data = agile_chart[:class].data(@issues, options) if agile_chart

    if data
      data[:chart] = @chart
      data[:chart_unit] = options[:chart_unit]
      return render json: data
    end

    raise ActiveRecord::RecordNotFound
  end

  #### Quanlity #####
  def get_bug_count_by_status_chart_data
    # Lấy custom field "Discovery Stage"
    discovery_stage_field = CustomField.find_by(name: 'Discovery Stage')

    # Kiểm tra nếu custom field "Discovery Stage" không tồn tại
    if discovery_stage_field.nil?
      render json: { error: 'Custom Field "Discovery Stage" not found' }, status: :not_found
      return
    end

    # Lấy tất cả các issue có tracker là "Bug" trong project và version hiện tại
    bugs = @project.issues.where(tracker: Tracker.find_by(name: 'Bug'), fixed_version: @current_version)

    # Phân nhóm theo status và đếm số lượng bug theo từng trạng thái
    development_uat_bug_count = bugs.group(:status_id).count

    uat_bug_count = bugs
                        .joins(:custom_values)
                        .where(custom_values: { custom_field_id: discovery_stage_field.id, value: "UAT" })
                        .group(:status_id)
                        .count

    production_bug_count = @project.issues.where(tracker: Tracker.find_by(name: 'Bug - Production'), fixed_version: @current_version).group(:status_id).count

    # Tính toán số lượng development bugs (bug_status_counts - uat_bug_count)
    development_bug_count = development_uat_bug_count.dup
    uat_bug_count.each do |status_id, count|
      # Trừ đi số lượng UAT bugs từ bug_status_counts để có số lượng development bugs
      development_bug_count[status_id] -= count
    end

    # Tạo dữ liệu cho biểu đồ cột chồng
    all_status_ids = (development_uat_bug_count.keys + production_bug_count.keys).uniq
    status_labels = IssueStatus.where(id: all_status_ids).pluck(:name)
    uat_counts = []
    production_counts = []
    development_counts = []

    # Chuẩn bị dữ liệu cho từng loại bug theo từng status
    status_labels.each do |status|
      status_id = IssueStatus.find_by(name: status).id

      # Lấy số lượng của từng loại bug, mặc định là 0 nếu không có dữ liệu
      uat_counts << (uat_bug_count[status_id] || 0)
      production_counts << (production_bug_count[status_id] || 0)
      development_counts << (development_bug_count[status_id] || 0)
    end

    # Trả về dữ liệu cho frontend dưới dạng JSON
    render json: {
      labels: status_labels,
      datasets: [
        {
          label: 'Development Bugs',
          data: development_counts,
          backgroundColor: 'rgba(75, 192, 192, 0.2)',  # Màu cho development bugs
          borderColor: 'rgba(75, 192, 192, 1)',
          borderWidth: 1
        },
        {
          label: 'UAT Bugs',
          data: uat_counts,
          backgroundColor: 'rgba(54, 162, 235, 0.2)',  # Màu cho production bugs
          borderColor: 'rgba(54, 162, 235, 1)',
          borderWidth: 1
        },
        {
          label: 'Production Bugs',
          data: production_counts,
          backgroundColor: 'rgba(255, 99, 132, 0.2)',  # Màu cho UAT bugs
          borderColor: 'rgba(255, 99, 132, 1)',
          borderWidth: 1
        },
      ]
    }
  end

  def bug_by_user_story_chart_data
    # Lấy custom field "Discovery Stage"
    discovery_stage_field = CustomField.find_by(name: 'Discovery Stage')

    # Kiểm tra nếu custom field "Discovery Stage" không tồn tại
    if discovery_stage_field.nil?
      render json: { error: 'Custom Field "Discovery Stage" not found' }, status: :not_found
      return
    end

    # Lấy tất cả các issue có tracker là "Bug" và liên kết với các User Stories (issues parent)
    @bugs = @project.issues.where(tracker: Tracker.find_by(name: 'Bug'), fixed_version: @current_version)

    # Group bugs theo user story (parent issue)
    @user_stories = @project.issues.where(tracker: Tracker.find_by(name: 'Story'), fixed_version: @current_version)  # Lấy tất cả user stories (issues cha)

    # Lấy các giá trị của "Discovery Stage" (UT, IT, ST, UAT)
    discovery_stages = discovery_stage_field.possible_values
    
    # Lưu trữ dữ liệu số lượng bugs cho từng user story và discovery stage
    @bug_counts = @user_stories.map do |user_story|
      # Group bugs của mỗi user story theo Discovery Stage
      category_counts = discovery_stages.map do |stage|
        bug_count = @bugs.where(parent_id: user_story.id)
                        .joins(:custom_values)
                        .where(custom_values: { custom_field_id: discovery_stage_field.id, value: stage })
                        .count
        { stage: stage, count: bug_count }
      end

      # Đếm bugs mà không có Discovery Stage (null hoặc không có giá trị)
      other_bug_count = @bugs.where(parent_id: user_story.id)
                .joins("LEFT JOIN custom_values ON custom_values.customized_id = issues.id AND custom_values.customized_type = 'Issue' AND custom_values.custom_field_id = #{discovery_stage_field.id}")
                .where("custom_values.value IS NULL OR custom_values.id IS NULL")
                .count

      # Thêm "Other" vào danh sách Discovery Stage nếu có bugs không có giá trị Discovery Stage
      category_counts << { stage: 'Discovery Stage not selected', count: other_bug_count }

      { user_story_name: user_story.subject, category_counts: category_counts }
    end

    # Trả về dữ liệu cho frontend dưới dạng JSON
    render json: {
      labels: @bug_counts.map { |data| data[:user_story_name] },  # Các user stories
      datasets: discovery_stages.map do |stage|
        {
          label: stage,
          data: @bug_counts.map { |data| data[:category_counts].find { |c| c[:stage] == stage }[:count] }
        }
      end.concat([{  # Thêm dữ liệu cho "Other"
        label: 'Discovery Stage not selected',
        data: @bug_counts.map { |data| data[:category_counts].find { |c| c[:stage] == 'Discovery Stage not selected' }[:count] }
      }])
    }
  end

  def bugs_by_problem_category_chart_data
    # Lấy tất cả các issue có tracker là "Bug" trong project và version hiện tại
    @bugs = @project.issues.where(tracker: Tracker.find_by(name: 'Bug'), fixed_version: @current_version)

    # Lấy danh sách các giá trị của custom field "Problem Category"
    problem_category_field = CustomField.find_by(name: 'Problem Category')
    if problem_category_field.nil?
      render json: { error: 'Custom Field "Problem Category" not found' }, status: :not_found
      return
    end

    discovery_stage_field = CustomField.find_by(name: 'Discovery Stage')
    # Kiểm tra nếu custom field "Discovery Stage" không tồn tại
    if discovery_stage_field.nil?
      render json: { error: 'Custom Field "Discovery Stage" not found' }, status: :not_found
      return
    end

    problem_categories = problem_category_field.enumerations.pluck(:id, :name)

    # Đếm số lượng bugs theo từng giá trị của Problem Category
    @category_counts = problem_categories.map do |category|
      bug_count = @bugs.joins(:custom_values).where(custom_values: { custom_field_id: problem_category_field.id, value: category[0] }).count

      uat_bug_count = @bugs
      .joins(:custom_values)  # Inner Join với custom_values
      .where("custom_values.custom_field_id = ? AND custom_values.value = 'UAT'", discovery_stage_field.id)
      .or(@project.issues.joins(:custom_values)
                        .where("custom_values.custom_field_id = ? AND custom_values.value = ?", problem_category_field.id, category[0]))
      .group("issues.id")  # Nhóm theo bug.id
      .having("COUNT(issues.id) = 2")  # Lọc bugs có COUNT = 

      { category_name: category[1], dev_bug_count: bug_count - uat_bug_count.length, uat_bug_count: uat_bug_count.length }
    end

    # Trả về dữ liệu cho frontend
    render json: {
      labels: @category_counts.map { |data| data[:category_name] },
      datasets: [
        {
          label: "Development",
          data: @category_counts.map { |data| data[:dev_bug_count] }
        },
        {
          label: "UAT",
          data: @category_counts.map { |data| data[:uat_bug_count] }
        }
      ]
    }
  end

  def calculate_story_points_for_custom_field(custom_field_name, trackers, statuses)
    custom_field = CustomField.find_by(name: custom_field_name)
    # Kiểm tra nếu custom field không tồn tại
    return nil if custom_field.nil?

    @project.issues
      .joins(:custom_values)
      .where(tracker: trackers, fixed_version: @current_version)
      .where(status: statuses)
      .where(custom_values: { custom_field_id: custom_field.id })
      .sum("CAST(custom_values.value AS INTEGER)")  # Tính tổng Story Points (giả sử value là kiểu số)
  end

  def get_active_sprint_sp_data(trackers, statuses)
    sp_team = @project.issues
    .joins(:agile_data)
    .where(tracker: trackers, fixed_version: current_version)
    .where(status: statuses)
    .sum('agile_data.story_points')

    sp_backend = calculate_story_points_for_custom_field('Story Point - Backend', trackers, statuses)
    if sp_backend.nil?
      return { error: 'Custom field "Story Point - Backend" not found' }
    end
  
    sp_frontend = calculate_story_points_for_custom_field('Story Point - Frontend', trackers, statuses)
    if sp_frontend.nil?
      return { error: 'Custom field "Story Point - Frontend" not found' }
    end
  
    sp_tester = calculate_story_points_for_custom_field('Story Point - Tester', trackers, statuses)
    if sp_tester.nil?
      return { error: 'Custom field "Story Point - Tester" not found' }
    end

    {
      sp_team: sp_team,
      sp_backend: sp_backend,
      sp_frontend: sp_frontend,
      sp_tester: sp_tester
    }
  end

  def get_active_sprint_velocity_chart_data
    trackers = Tracker.find_by(name: ['Story', 'Bug - Production'])

    # Commit
    statuses_commit = IssueStatus.find_by(name: ['Committed In Sprint', 'Done Development', 'UAT', 'UAT Feedback', 'Done', 'Wait For Release', "Closed"])
    commit_data = get_active_sprint_sp_data(trackers, statuses_commit)

    # Done
    statuses_done = IssueStatus.find_by(name: ['Done','Wait For Release', 'Closed'])
    done_data = get_active_sprint_sp_data(trackers, statuses_done)

    render json: {
      sp_commit: commit_data[:sp_team],
      sp_backend_commit: commit_data[:sp_backend],
      sp_frontend_commit: commit_data[:sp_frontend],
      sp_tester_commit: commit_data[:sp_tester],
      sp_done: done_data[:sp_team],
      sp_backend_done: done_data[:sp_backend],
      sp_frontend_done: done_data[:sp_frontend],
      sp_tester_done: done_data[:sp_tester],
    }
  end

  def get_blocked_issue_chart_data
    blocked_status_id = IssueStatus.find_by(name: 'Blocked').id  # ID của status "Blocked"

    # Tìm ra các issue có blocked trong version
    blocked_issues = @project.issues
      .joins(:journals)
      .joins("INNER JOIN journal_details ON journal_details.journal_id = journals.id")
      .where(journal_details: { property: 'attr', value: blocked_status_id })  # Lọc theo trạng thái "Blocked"
      .where('journals.created_on BETWEEN ? AND ?', @current_version.start_date, @current_version.due_date)  # Lọc theo thời gian trong version

    blocked_issue_ids = blocked_issues.pluck(:id)

    # Truy vấn tất cả các issues có id trùng với blocked_issue_ids
    issues_with_blocked_ids = @project.issues.where(id: blocked_issue_ids)

    # Biến để lưu trữ số lượng issues "Blocked" theo từng ngày
    daily_blocked_counts = Hash.new(0)
    current_date = Date.today
  
    logger.info "issue ne: #{blocked_issues.inspect}"
    # Duyệt qua tất cả các journal và nhóm theo ngày
    issues_with_blocked_ids.each do |issue|
      date_issue_state_blocked = Hash.new(false)
      version_range = generate_date_range(@current_version.start_date, @current_version.due_date)
      version_range.each do |date|
        date_issue_state_blocked[date] = false
      end

      # Duyệt qua từng journal của issue để lấy created_on
      issue.journals.each do |journal|
        if journal.created_on.present?
          # Lấy ngày thay đổi trạng thái (journal.created_on) và nhóm theo ngày
          date = journal.created_on.to_date
          date_range = generate_date_range(date, current_date)

          journal.details.each do |detail|
            if detail.property == "attr"
              logger.info "journal date: #{date}"
              date_range.each do |date_item|
                daily_blocked_counts[date_item] ||= 0
                if detail.value.to_i == blocked_status_id && date_issue_state_blocked[date_item] == false
                  logger.info "detail value ne: #{issue.id} value: #{detail.value} date: #{date_item}, count: #{daily_blocked_counts[date_item]}"
                  date_issue_state_blocked[date_item] = true
                  daily_blocked_counts[date_item] += 1 
                elsif daily_blocked_counts[date_item] > 0 && date_issue_state_blocked[date_item] == true
                  logger.info "vao tru ne: #{date_item}"
                  date_issue_state_blocked[date_item] = false
                  daily_blocked_counts[date_item] -= 1
                end
              end
            end
          end
        end
      end
    end
      
    # Chuẩn bị dữ liệu cho frontend
    labels = daily_blocked_counts.keys  # Các ngày
    data = daily_blocked_counts.values  # Số lượng issues mỗi ngày
  
    # Trả về dữ liệu cho chart
    render json: {
      labels: labels,
      data: data
    }
  end

  def bug_production_not_closed_by_priority_chart_data
    # Lấy tất cả các "status" không được tích chọn "close issue" (ví dụ: trạng thái không có checkbox "close issue")
    # Giả sử có một trường boolean trong bảng "status" tên là "close_issue"
    status_ids_not_closed = IssueStatus.where(is_closed: false).pluck(:id)
  
    # Lấy các issues có tracker là "Bug - Production" và trạng thái không phải là "close issue"
    bug_production_issues = @project.issues
      .where(tracker: Tracker.find_by(name: 'Bug - Production'))
      .where(status_id: status_ids_not_closed)  # Chỉ lấy những status không phải là "close issue"
    
    # Nhóm các issues theo priority và đếm số lượng issues trong mỗi nhóm
    issue_counts = bug_production_issues
      .group(:priority_id)  # Nhóm theo priority
      .count

    priorities = IssuePriority
    
    # Tạo dữ liệu cho biểu đồ
    labels = IssuePriority.pluck(:name)  # Tên của các priority
    counts = priorities.pluck(:id).map do |priority_id|
      issue_counts[priority_id] || 0
    end

    render json: {
      labels: labels,
      counts: counts
    }
  end

  def get_current_version
    if @current_version
      render json: {
        version_id: @current_version.id,
        version_name: @current_version.name,
        description: @current_version.description,
        start_date: @current_version.start_date,
        effective_date: @current_version.effective_date,
        due_date: @current_version.due_date,
        status: @current_version.status,
        created_on: @current_version.created_on,
        updated_on: @current_version.updated_on
      }
    else
      render json: { error: 'No current version set' }, status: :not_found
    end
  end

  private

  def find_project
    @project = Project.find(params[:project_id])
  end

  def current_version
    @current_version = Version.find(@project.default_version_id)
  end

  def generate_date_range(start_date, end_date)
    (start_date..end_date).to_a  # Sử dụng toán tử Range để tạo danh sách các ngày
  end
end
