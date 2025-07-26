RedmineApp::Application.routes.draw do
  resources :projects do
    get 'agile_metrics', to: 'agile_metrics#index'
  end

  get 'projects/:project_id/metrics/velocity_chart', to: 'agile_metrics#get_velocity_chart_data', format: 'json'
  get 'projects/:project_id/metrics/issue_status_pie_chart', to: 'agile_metrics#get_issue_status_pie_data', format: 'json'
  get 'projects/:project_id/metrics/burndown_chart', to: 'agile_metrics#get_burndown_chart_data', format: 'json'
  get 'projects/:project_id/metrics/bug_count_by_status_chart', to: 'agile_metrics#get_bug_count_by_status_chart_data', format: 'json'
  get 'projects/:project_id/metrics/bug_by_user_story_chart', to: 'agile_metrics#bug_by_user_story_chart_data', format: 'json'
  get 'projects/:project_id/metrics/bugs_by_problem_category_chart', to: 'agile_metrics#bugs_by_problem_category_chart_data', format: 'json'
  get 'projects/:project_id/metrics/active_sprint_velocity_chart', to: 'agile_metrics#get_active_sprint_velocity_chart_data', format: 'json'
  get 'projects/:project_id/metrics/blocked_issue_chart', to: 'agile_metrics#get_blocked_issue_chart_data', format: 'json'
  get 'projects/:project_id/metrics/bug_production_not_closed_by_priority_chart', to: 'agile_metrics#bug_production_not_closed_by_priority_chart_data', format: 'json'
end
