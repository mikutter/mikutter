# -*- coding: utf-8 -*-

require "mikutwitter/basic"

class MikuTwitter::Error < StandardError
  attr_accessor :httpresponse

  def initialize(text, httpresponse)
    super(text)
    @httpresponse = httpresponse
  end
end

class MikuTwitter::TwitterError < MikuTwitter::Error
  def self.inherited(klass)
    self.errors << klass end

  def self.errors
    @errors ||= Set.new end

  def self.[](code)
    self.errors.find{|e|e.code==code} || MikuTwitter.TwitterError(code)
  end

  def code
    self.class.code end
end

def MikuTwitter.TwitterError(code=nil)
  if code
    Class.new(MikuTwitter::TwitterError) do
      define_singleton_method(:code) { code } end
  else
    MikuTwitter::TwitterError end end

MikuTwitter::CouldNotAuthenticateError = Class.new(MikuTwitter::TwitterError(32))
MikuTwitter::SpecifiedResourceWasNotFoundEerror = Class.new(MikuTwitter::TwitterError(34))
MikuTwitter::AttachmentURLParameterIsInvalidEerror = Class.new(MikuTwitter::TwitterError(44))
MikuTwitter::SuspendOrNotPermittedError = Class.new(MikuTwitter::TwitterError(64))
MikuTwitter::APIVersionTooOldError = Class.new(MikuTwitter::TwitterError(68))
MikuTwitter::RateLimitError = Class.new(MikuTwitter::TwitterError(88))
MikuTwitter::InvalidOrExpiredTokenError = Class.new(MikuTwitter::TwitterError(89))
MikuTwitter::ProtocolError = Class.new(MikuTwitter::TwitterError(92))
MikuTwitter::FlyingWhaleError = Class.new(MikuTwitter::TwitterError(130))
MikuTwitter::InternalError = Class.new(MikuTwitter::TwitterError(131))
MikuTwitter::OAuthTimestampOutOfRangeError = Class.new(MikuTwitter::TwitterError(135))
MikuTwitter::NoStatusFoundWithThatIDError = Class.new(MikuTwitter::TwitterError(144))
MikuTwitter::FollowLimitError = Class.new(MikuTwitter::TwitterError(161))
MikuTwitter::ProtectedStatusError = Class.new(MikuTwitter::TwitterError(179))
MikuTwitter::DailyStatusUpdateLimitError = Class.new(MikuTwitter::TwitterError(185))
MikuTwitter::DuplicatedStatusError = Class.new(MikuTwitter::TwitterError(187))
MikuTwitter::BadAuthenticationDataError = Class.new(MikuTwitter::TwitterError(215))
MikuTwitter::RheniumError = Class.new(MikuTwitter::TwitterError(226))
MikuTwitter::ShouldNotBeUsedThisEndpointError = Class.new(MikuTwitter::TwitterError(251))
MikuTwitter::DontHaveWriteAccessError = Class.new(MikuTwitter::TwitterError(261))
MikuTwitter::CantMuteYourselfError = Class.new(MikuTwitter::TwitterError(271))
MikuTwitter::NotMutingError = Class.new(MikuTwitter::TwitterError(272))
MikuTwitter::DirectMessageExceedTheNumberOfCharacterError = Class.new(MikuTwitter::TwitterError(354))
MikuTwitter::InReplyToStatusIdDoesNotExistError = Class.new(MikuTwitter::TwitterError(385))
MikuTwitter::TooManyAttachmentResourceError = Class.new(MikuTwitter::TwitterError(386))
