class CategoryRulesController < ApplicationController
  def create
    @category = Category.find(params[:category_id])
    @rule = @category.category_rules.build(rule_params)

    if @rule.save
      redirect_to edit_category_path(@category), notice: "Rule added."
    else
      redirect_to edit_category_path(@category), alert: "Could not add rule: #{@rule.errors.full_messages.join(', ')}"
    end
  end

  def destroy
    @rule = CategoryRule.find(params[:id])
    @category = @rule.category
    @rule.destroy
    redirect_to edit_category_path(@category), notice: "Rule removed."
  end

  private

  def rule_params
    params.require(:category_rule).permit(:pattern, :match_type)
  end
end
