extern char *botScript;
extern boolean inGame;

void resetBot(char *filename);
boolean botShouldAct();
void nextBotEvent(rogueEvent *returnEvent);
