class PostOwnerChanger

  def initialize(params)
    @post_ids = params[:post_ids]
    @topic = Topic.with_deleted.find_by(id: params[:topic_id].to_i)
    @new_owner = params[:new_owner]
    @acting_user = params[:acting_user]
    @skip_revision = params[:skip_revision] || false

    raise ArgumentError unless @post_ids && @topic && @new_owner && @acting_user
  end

  def change_owner!
    @post_ids.each do |post_id|
      post = Post.with_deleted.where(id: post_id, topic_id: @topic.id).first
      next if post.blank?
      @topic.user = @new_owner if post.is_first_post?

      if post.user == nil
        @topic.recover! if post.is_first_post?
      end
      post.topic = @topic
      post.set_owner(@new_owner, @acting_user, @skip_revision)
      PostAction.remove_act(@new_owner, post, PostActionType.types[:like])

      @topic.update_statistics

      @new_owner.user_stat.update(
        first_post_created_at: @new_owner.reload.posts.order('created_at ASC').first&.created_at
      )

      @topic.save!(validate: false)
    end
  end
end
