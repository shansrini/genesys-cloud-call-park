terraform {
  required_providers {
    genesyscloud = {
      source  = "mypurecloud/genesyscloud"
      version = "1.39.0"
    }
  }
}

/*
  Create a Data Action integration
*/
module "data_action" {
  source                          = "git::https://github.com/GenesysCloudDevOps/public-api-data-actions-integration-module?ref=main"
  integration_name                = "Orbit Data Actions OAuth Integration"
  integration_creds_client_id     = var.client_id
  integration_creds_client_secret = var.client_secret
}

/*
  Get Waiting Calls
*/
module "get_waiting_calls" {
  source          = "./modules/data-actions/get-waiting-calls-in-specific-queue-based-on-external-tag"
  action_name     = "Get Waiting Calls on Specific Queue Base on External Tag"
  action_category = module.data_action.integration_name
  integration_id  = module.data_action.integration_id
}

/*
  Replace Participant With ANI
*/
module "replace_participant_with_ani" {
  source          = "./modules/data-actions/replace-participant-with-ani"
  action_name     = "Replace Participant with ANI"
  action_category = module.data_action.integration_name
  integration_id  = module.data_action.integration_id
}


/*
  Update External Tag Conversation
*/
module "update_external_tag_conversation" {
  source          = "./modules/data-actions/update-external-tag-on-conversation"
  action_name     = "Update External Tag on Conversation"
  action_category = module.data_action.integration_name
  integration_id  = module.data_action.integration_id
}

/*
  Default In-queue flow
*/

module "default_in_queue_flow" {
  source        = "./modules/flows/default-in-queue-flow"
  flow_name     = "Default In-Queue Flow"
  division_name = var.division_name
}


/*
  In-queue flow orbit parked hold
*/
module "in_queue_flow_orbit_park_hold" {
  source        = "./modules/flows/in-queue-flow-orbit-park-hold"
  flow_name     = "InQueue - Orbit Call Park Hold"
  division_name = var.division_name
}

/*
  Call Park - Agent Inbound Flow
*/
module "call_park_agent_inbound_flow" {
  source             = "./modules/flows/call-park-agent-inbound-flow"
  flow_name          = "Call Park Agent - Inbound Flow"
  division_name      = var.division_name
  in_queue_flow_name = "InQueue - Orbit Call Park Hold"
  depends_on         = [module.in_queue_flow_orbit_park_hold]
}

/*
  Orbit - Parked Call Retrieval
*/
module "orbit_parked_call_retrieval" {
  source               = "./modules/flows/orbit-parked-call-retrieval"
  data_action_category = module.data_action.integration_name
  data_action_name_1   = module.get_waiting_calls.action_name
  data_action_name_2   = module.replace_participant_with_ani.action_name
  data_action_name_3   = module.update_external_tag_conversation.action_name
  queue_id             = var.queue_id
  flow_name            = "Orbit - Parked Call Retrieval"
  depends_on           = [module.in_queue_flow_orbit_park_hold, module.data_action, module.get_waiting_calls, module.replace_participant_with_ani, module.update_external_tag_conversation]
  division_name        = var.division_name

}

/*
  Add Script
*/
module "script" {
  source           = "./modules/script"
  script_name      = "Orbit Queue Transfer"
  data_action_name = module.update_external_tag_conversation.action_name
  data_action_id   = module.update_external_tag_conversation.action_id
  org_id           = var.org_id
  queue_id         = var.queue_id
  depends_on       = [module.update_external_tag_conversation]
}





