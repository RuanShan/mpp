class Mobile::RecommendsController < Mobile::BaseController
  layout 'mobile/recommends'
  before_action :block_non_wx_browser
  before_action :find_activity, :check_subscribe, :find_participate

  def index
    @possible_prize = nil
    @possible_prize = @activity.activity_prizes.active.find  do |prize|
      prize.recommends_count - @invites.count <= 0
    end

    if params[:origin_openid].present? && params[:origin_openid] != @wx_user.openid
      from_user = WxUser.where(openid: params[:origin_openid], wx_mp_user_id: @wx_mp_user.id).first.user
      if from_user.present?
        from_user_participate =  WxParticipate.normal.where(user_id: from_user.id, activity_id: @activity.id).first
        if !@subscribed
         wx_invites = WxInvite.where(wx_invitable_id: @activity.id, wx_invitable_type: 'Activity', to_user_id: @user.id, is_recommend: true)
         if wx_invites.blank?
          begin
            invite = wx_invites.create(from_user_id: from_user.id, wx_participate_id: from_user_participate.id)
            #服务号的逻辑在关注后触发
            if @wx_mp_user.try(:subscribe?) || @wx_mp_user.try(:auth_subscribe?)
              invite.recommended!
            end
          rescue => e
            Rails.logger.warn "failed to create wx_invite : #{e}"
          end
         end
        end
      end
    end
  end

  def prize
    return redirect_to mobile_recommends_url(activity_id: @activity.id, openid: @wx_user.openid, origin_openid: params[:origin_openid]) if (@prizes.blank? && @gift.blank?)
  end

  def user
    return redirect_to mobile_recommends_url(activity_id: @activity.id, openid: @wx_user.openid, origin_openid: params[:origin_openid]) if (@prizes.blank? && @gift.blank?)
  end

  def update_info
      prize = ActivityPrize.find_by_id(params[:prize_id])
      if prize.present?
        base_count =  prize.prize_count - prize.consumes.count
        limit_count =  prize.recommends_count - @invites.count
        if base_count > 0 && limit_count <= 0
          consume = prize.consumes.create(site_id: @site_id, user_id: @user.id, consumable_type: 'Activity', consumable_id: @activity.id, expired_at:  @activity.end_at, mobile: params[:mobile])
          consume.auto_use_point_prize_consume!
          @participate.update_attributes(prize_status: WxParticipate::GOT_PRIZE, prize_title: prize.title)
          @user.update_attributes(mobile: params[:mobile])
          @participate.drop!
        end
      end
    render json: {status: 'ok' }
  end

  private

    def check_subscribe
      @subscribed = false
      @auth_service = false
      if @wx_mp_user.try(:authorized_auth_subscribe?) && @wx_user.present?
        attrs = Weixin.get_wx_user_info(@wx_mp_user, @wx_user.openid)
        if attrs.present?
          @auth_service = true
          if attrs['nickname'].present?
            origin_nickname = attrs['nickname']
            attrs['nickname'] = ''
            origin_nickname.each_char { |char|  attrs['nickname']  << char unless char.ord > 65534   }
          end
          @wx_user.update_attributes(attrs)
          if @wx_user.subscribe?
            @subscribed = true
          end
        end
      end
      render_404 unless @wx_user
    end

    def find_participate
      @participate = WxParticipate.normal.where(user_id: @user.id, activity_id: @activity.id).first_or_create
      @prizes = @user.consumes.includes(:activity_prize).where(consumable_type: 'Activity', consumable_id: @activity.id).where("activity_prize_id is not null").order("created_at DESC") rescue []
      @gift = @user.wx_prizes.where(activity_id: @activity.id).reached.first
      @invites = @participate.wx_invites.recommend.recommended
    end

    def find_activity
      @activity = Activity.recommend.show.find_by_id(session[:activity_id])
      return render_404 unless @activity
      session[:activity_id] ||= params[:activity_id]
      @share_title = "好友向你推荐关注 #{ @wx_mp_user.try(:nickname) } 公众号！"
      @share_desc = @activity.summary.try(:squish)
      @share_image = "/assets/recommend.jpg"
    end
end
