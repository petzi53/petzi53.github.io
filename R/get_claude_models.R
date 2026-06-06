# R/get_claude_models.R
# get Claude models, save them into a tibble and print them

# Retrieve list of available Claude models
available_claude_models <- tibble::as_tibble(ellmer::models_anthropic())
print(available_claude_models)
