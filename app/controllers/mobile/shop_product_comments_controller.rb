class Mobile::ShopProductCommentsController < Mobile::BaseController

  def create
    @shop_product_comment = ShopProductComment.new(params[:shop_product_comment])
    respond_to do |format|
      format.js {}
    end
  end

end