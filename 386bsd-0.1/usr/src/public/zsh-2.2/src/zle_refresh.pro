void resetvideo DCLPROTO((void));
int scrollwindow DCLPROTO((void));
void refresh DCLPROTO((void));
void refreshline DCLPROTO((int ln));
void moveto DCLPROTO((int ln,int cl));
void tcmultout DCLPROTO((int cap,int multcap,int ct));
void tc_rightcurs DCLPROTO((int ct));
void tc_downcurs DCLPROTO((int ct));
void tcout DCLPROTO((int cap));
void tcoutarg DCLPROTO((int cap,int arg));
void clearscreen DCLPROTO((void));
void redisplay DCLPROTO((void));
void trashzle DCLPROTO((void));
void singlerefresh DCLPROTO((void));
void singmoveto DCLPROTO((int pos));
int streqct DCLPROTO((char *s,char *t));
