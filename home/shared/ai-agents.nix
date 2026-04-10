{ pkgs, ... }:
{
  home.packages = with pkgs; [
    amp-cli
  ];
  programs.gemini-cli = {
    enable = true;
  };
  programs.claude-code = {
    enable = true;
  };
  programs.opencode = {
    enable = true;
    settings = {
      provider = {
        litellm = {
          npm = "@ai-sdk/openai-compatible";
          options = {
            apiKey = "sk-***";
            baseURL = "https://api.mammouth.ai/v1";
          };
          # models = {
          #   "gpt-4.1" = {
          #     name = "GPT 4.1 (mammouth.ai)";
          #   };
          #   claude-4-sonnet-20250522 = {
          #     name = "Claude 4 Sonnet (mammouth.ai)";
          #   };
          # };
        };
      };
    };
  };
}
