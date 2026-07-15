data "azurerm_policy_definition_built_in" "require_tag" {
  display_name = "Require a tag on resources"
}

resource "azurerm_resource_group_policy_assignment" "require_tag" {
  name                 = "require-${var.required_tag_name}-tag"
  resource_group_id    = var.resource_group_id
  policy_definition_id = data.azurerm_policy_definition_built_in.require_tag.id

  parameters = jsonencode({
    tagName = {
      value = var.required_tag_name
    }
  })
}
