#define BROGUEBOT_VERSION_STRING "1.0-rc1"

extern char *botScript;
extern boolean botControl;
extern short botMode;
extern short botAction;

void resetBot(char *filename);
void nextBotEvent(rogueEvent *returnEvent);
void botReport();
void magicMapped();

void calculateKnownDistances   (short **distanceMap,
                                unsigned long blockingTerrainFlags,
                                boolean monstersBlock);
