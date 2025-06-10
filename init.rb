Redmine::Plugin.register :redmine_agile_metrics do
  name 'Redmine Agile Metrics plugin'
  author 'Author name'
  description 'This is a plugin for Redmine'
  version '0.0.1'
  url 'http://example.com/path/to/plugin'
  author_url 'http://example.com/about'

  project_module :agile_metrics do
    permission :view_agile_metrics, { agile_metrics: [:index] }, public: true
  end

  menu :project_menu,
       :agile_metrics,
       { controller: 'agile_metrics', action: 'index' },
       caption: 'Agile Metrics',
       after: :activity,
       param: :project_id
end
