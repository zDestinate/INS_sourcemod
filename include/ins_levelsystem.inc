#if defined _ins_levelsystem_included
  #endinput
#endif
#define _ins_levelsystem_included

native LS_GetClientScore(int client);
native LS_GetClientRank(int client);
native LS_AddClientScore(int client, int score);
native LS_RemoveClientScore(int client, int score);
native LS_AddClientScorePenalty(int client, int score);
native LS_RemoveClientScorePenalty(int client, int score);
