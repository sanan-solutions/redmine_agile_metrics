class AgileMetricsController < ApplicationController
  before_action :find_project
  before_action :authorize

  def index
    # Velocity Chart
    @versions = @project.shared_versions.sorted
    @velocity_data = @versions.map do |version|
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

  private

  def find_project
    @project = Project.find(params[:project_id])
  end
end
