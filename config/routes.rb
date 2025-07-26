RedmineApp::Application.routes.draw do
  resources :projects do
    get 'agile_metrics', to: 'agile_metrics#index'
  end

  get 'api/projects/:project_id/velocity_chart', to: 'agile_metrics#get_velocity_chart_data', format: 'json'
  get 'api/projects/:project_id/issue_status_pie_chart', to: 'agile_metrics#get_issue_status_pie_data', format: 'json'
  get 'api/projects/:project_id/burndown_chart', to: 'agile_metrics#get_burndown_chart_data', format: 'json'
  get 'api/projects/:project_id/bug_count_by_status_chart', to: 'agile_metrics#get_bug_count_by_status_chart_data', format: 'json'
  get 'api/projects/:project_id/bug_by_user_story_chart', to: 'agile_metrics#bug_by_user_story_chart_data', format: 'json'
  get 'api/projects/:project_id/bugs_by_problem_category_chart', to: 'agile_metrics#bugs_by_problem_category_chart_data', format: 'json'
  get 'api/projects/:project_id/active_sprint_velocity_chart', to: 'agile_metrics#get_active_sprint_velocity_chart_data', format: 'json'
  get 'api/projects/:project_id/blocked_issue_chart', to: 'agile_metrics#get_blocked_issue_chart_data', format: 'json'
  get 'api/projects/:project_id/bug_production_not_closed_by_priority_chart', to: 'agile_metrics#bug_production_not_closed_by_priority_chart_data', format: 'json'
end
