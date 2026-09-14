# 投稿前フィルタ。NGワードを含む場合はroomへbroadcastせず、送信者本人にのみ
# ChatChannel の個人向けstream経由で警告する(Chat::StreamsController#create から呼ぶ)。
# 検証用に "test" のみを対象にしている。
module MessageFilter
  BANNED_WORDS = ["test"].freeze

  def self.blocked?(content)
    return false if content.blank?

    BANNED_WORDS.any? { |word| content.include?(word) }
  end
end
