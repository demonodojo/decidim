# frozen_string_literal: true

module Decidim
  class AmendmentsController < Decidim::ApplicationController
    include Decidim::ApplicationHelper
    include FormFactory

    before_action :authenticate_user!
    helper_method :amendable, :emendation

    def new
      @form = Decidim::Amendable::CreateForm.from_params(params)
    end

    def create
      @form = form(Decidim::Amendable::CreateForm).from_params(params)
      enforce_permission_to :create, :amendment, current_component: @form.component
      Decidim::Amendable::Create.call(@form) do
        on(:ok) do
          flash[:notice] = t("created.success", scope: "decidim.amendments")
          redirect_to Decidim::ResourceLocatorPresenter.new(@amendable).path
        end

        on(:invalid) do
          flash[:alert] = t("created.error", scope: "decidim.amendments")
          render :new
        end
      end
    end

    def reject
      @form = form(Decidim::Amendable::RejectForm).from_params(params)
      enforce_permission_to :reject, :amendment, amendment: @form.amendable, current_component: @form.component

      Decidim::Amendable::Reject.call(@form) do
        on(:ok) do
          flash[:notice] = t("rejected.success", scope: "decidim.amendments")
        end

        on(:invalid) do
          flash[:alert] = t("rejected.error", scope: "decidim.amendments")
        end
        redirect_to Decidim::ResourceLocatorPresenter.new(@emendation).path
      end
    end

    def promote
      @form = Decidim::Amendable::PromoteForm.from_params(params)
      enforce_permission_to :promote, :amendment, amendment: @form.emendation, current_component: @form.component

      Decidim::Amendable::Promote.call(@form) do
        on(:ok) do |proposal|
          flash[:notice] = I18n.t("promoted.success", scope: "decidim.amendments")
          redirect_to Decidim::ResourceLocatorPresenter.new(proposal).path
        end

        on(:invalid) do
          flash.now[:alert] = t("promoted.error", scope: "decidim.amendments")
          redirect_to Decidim::ResourceLocatorPresenter.new(@emendation).path
        end
      end
    end

    def review
      @form = Decidim::Amendable::ReviewForm.from_params(params)
    end

    def accept
      @form = Decidim::Amendable::ReviewForm.from_params(params)
      enforce_permission_to :accept, :amendment, amendment: @form.amendable, current_component: @form.component

      Decidim::Amendable::Accept.call(@form) do
        on(:ok) do
          flash[:notice] = t("accepted.success", scope: "decidim.amendments")
          redirect_to Decidim::ResourceLocatorPresenter.new(@emendation).path
        end

        on(:invalid) do
          flash[:alert] = t("accepted.error", scope: "decidim.amendments")
          render :review
        end
      end
    end

    private

    def amendable_gid
      params[:amendable_gid] || params[:amendment][:amendable_gid]
    end

    def amendable
      @amendable ||= if amendable_gid
                       present(GlobalID::Locator.locate_signed(amendable_gid))
                     else
                       Decidim::Amendment.find_by(decidim_emendation_id: params[:id]).amendable
                     end
    end

    def emendation
      @emendation ||= present(Decidim::Amendment.find(params[:id]).emendation)
    end
  end
end
