module ScaptimonyReportDashboardHelper
  Colors = {
      :passed => '#89A54E',
      :failed => '#AA4643',
      :othered => '#DB843D',
  }


  def reports_breakdown_chart(report, options = {})
    data = []
    [[:failed, _('Failed')],
     [:passed, _('Passed')],
     [:othered, _('Othered')],
    ].each { |i|
      data << {:label => i[1], :data => report[i[0]], :color => Colors[i[0]]}
    }
    flot_pie_chart 'overview', _('Compliance reports breakdown'), data, options
  end

end