class InformationController < ApplicationController
  layout false

  def index
    @lists = [
      %w(2016/08/09 表示の高速化を行いました),
      %w(2016/08/06 表示の高速化を行いました),
      %w(2016/08/01 レイアウトの調整を行いました),
      %w(2016/07/31 通知ページを作成しました),
      %w(2016/07/28 検索を高速化しました),
      %w(2016/07/27 トップページのレイアウトを修正しました),
      %w(2016/07/26 トップページのレイアウトを修正しました),
      %w(2016/07/25 ページの読み込みを高速化しました),
      %w(2016/07/24 スマートフォン向けのアイコンを設置しました),
    ].freeze
    render json: {html: render_to_string}, status: 200
  end
end
