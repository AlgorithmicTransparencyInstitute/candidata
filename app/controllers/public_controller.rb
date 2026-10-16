# Base for the signed-out public site: the shared layout (header, footer,
# per-page title/meta) lives in layouts/public. Workspace controllers
# (admin, researcher, verification, demographics) don't inherit from this.
class PublicController < ApplicationController
  layout 'public'
end
