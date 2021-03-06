class Pro::BrochesController < Pro::HousesBaseController

  before_action :set_broche

  def index

  end

  def update_activity
    if @activity.update_attributes(params[:activity])
      flash[:notice] = '保存成功'
    else
      flash[:alert] = '保存失败'
    end
    redirect_to broches_path
  end

  private

  def set_broche
    @broche = current_site.broche
    @broche = current_site.create_broche unless @broche
    @activity = @broche.activity
  end
end
