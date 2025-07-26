Redmine::Plugin.register :redmine_agile_metrics do
  name 'Redmine Agile Metrics plugin'
  author 'Author name'
  description 'This is a plugin for Redmine'
  version '0.0.1'
  url 'http://example.com/path/to/plugin'
  author_url 'http://example.com/about'

  project_module :agile_metrics do
    permission :view_agile_metrics, { agile_metrics: [:index, :get_velocity_chart_data,:get_issue_status_pie_data,:get_burndown_chart_data,:get_bug_count_by_status_chart_data,:bug_by_user_story_chart_data,:bugs_by_problem_category_chart_data,:get_blocked_issue_chart_data,:get_active_sprint_velocity_chart_data,:bug_production_not_closed_by_priority_chart_data] }, public: true
  end

  menu :project_menu,
       :agile_metrics,
       { controller: 'agile_metrics', action: 'index' },
       caption: 'Agile Metrics',
       after: :agile,
       param: :project_id
end
