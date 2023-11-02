// qalgorithms_utils.cpp
#include "../include/qalgorithms_utils.h"

namespace q {

  int sum(const std::vector<int>& vec) {
    double sum = 0.0;
    for (const auto& elem : vec) {
        sum += elem;}
    return sum;}

  size_t sum(const std::vector<size_t>& vec) {
    double sum = 0.0;
    for (const auto& elem : vec) {
        sum += elem;}
    return sum;}

  double sum(const std::vector<double>& vec) {
    double sum = 0.0;
    for (const auto& elem : vec) {
        sum += elem;}
    return sum;}

  int sum(const bool* vec, size_t n) {
    int sum = 0;
    for (size_t i = 0; i < n; i++) {
      sum += vec[i];}
    return sum;}

  template <typename T>
  std::vector<bool> operator<(const std::vector<T>& vec, T scalar) {
    std::vector<bool> result(vec.size());
    int u = 0;
    for (const auto& elem : vec) {
        result[u] = elem < scalar;
        u++;
    }
    return result;
  }

  template <typename T>
  std::vector<bool> operator>(
    const std::vector<T>& vec, 
    T scalar) {
      std::vector<bool> result(vec.size());
      int u = 0;
      for (const auto& elem : vec) {
          result[u] = elem > scalar;
          u++;
      }
      return result;
  }

  template <typename T>
  std::vector<T> operator*(
    const std::vector<T>& A, 
    const std::vector<T>& B) {
      std::vector<T> product(A.size());
      for (size_t i = 0; i < A.size(); i++){
        product[i] = A[i] * B[i];
      }
      return product;
  }

  std::vector<bool> operator&&(
    const std::vector<bool>& A, 
    const std::vector<bool>& B) {
      std::vector<bool> result(A.size());
      for (size_t i = 0; i < A.size(); i++) {
        result[i] = A[i] & B[i];
      }
      return result;
  }

  std::vector<bool> operator!(const std::vector<bool>& A) {
    std::vector<bool> result(A.size());
    for (size_t i = 0; i < A.size(); i++) {
      result[i] = !A[i];
    }
    return result;
  }

  void operator|=(
    std::vector<bool>& A, 
    const std::vector<bool>& B) {
      for (size_t i = 0; i < A.size(); i++) {
        bool tempA = A[i];
        bool tempB = B[i];
        tempA |= tempB;
        A[i] = tempA;
      }
  }

  double erfi(const double x) {
    /* This function uses the Dawson Integral, i.e. 
    erfi(x) = 2 * Dawson * exp(x^2) / sqrt(pi) 
    
    The Dawson Integral is calculated by Stan Sykora's rational function approximations. URL : http://www.ebyte.it/library/codesnippets/DawsonIntegralApproximations.html (Dawson5())
    */
   // calculate the Dawson Integral:
   double y,p,q;
    y = x*x;
    p = 1.0 + y*(0.1049934947 + y*(0.0424060604
            + y*(0.0072644182 + y*(0.0005064034
            + y*(0.0001789971)))));
    q = 1.0 + y*(0.7715471019 + y*(0.2909738639
            + y*(0.0694555761 + y*(0.0140005442
            + y*(0.0008327945 + 2*0.0001789971*y)))));
    double D =  x*(p/q);

    return D * std::exp(x*x) * M_2_SQRTPI; //
  }

  tValues::tValues() {
    values = {
      {1,6.313751515},
      {2,2.91998558},
      {3,2.353363435},
      {4,2.131846781},
      {5,2.015048373},
      {6,1.94318028},
      {7,1.894578605},
      {8,1.859548038},
      {9,1.833112933},
      {10,1.812461123},
      {11,1.795884819},
      {12,1.782287556},
      {13,1.770933396},
      {14,1.761310136},
      {15,1.753050356},
      {16,1.745883676},
      {17,1.739606726},
      {18,1.734063607},
      {19,1.729132812},
      {20,1.724718243},
      {21,1.720742903},
      {22,1.717144374},
      {23,1.713871528},
      {24,1.71088208},
      {25,1.708140761},
      {26,1.70561792},
      {27,1.703288446},
      {28,1.701130934},
      {29,1.699127027},
      {30,1.697260894},
      {31,1.695518789},
      {32,1.693888742},
      {33,1.692360304},
      {34,1.690924251},
      {35,1.689572454},
      {36,1.688297711},
      {37,1.687093617},
      {38,1.685954458},
      {39,1.684875119},
      {40,1.683851011},
      {41,1.682878},
      {42,1.681952356},
      {43,1.681070702},
      {44,1.680229975},
      {45,1.679427392},
      {46,1.678660413},
      {47,1.677926721},
      {48,1.677224195},
      {49,1.676550892},
      {50,1.675905025},
      {51,1.67528495},
      {52,1.674689153},
      {53,1.674116236},
      {54,1.673564906},
      {55,1.673033965},
      {56,1.672522303},
      {57,1.672028888},
      {58,1.671552762},
      {59,1.671093032},
      {60,1.670648865},
      {61,1.670219484},
      {62,1.669804162},
      {63,1.669402222},
      {64,1.669013025},
      {65,1.668635976},
      {66,1.668270514},
      {67,1.667916114},
      {68,1.667572281},
      {69,1.667238549},
      {70,1.666914479},
      {71,1.666599658},
      {72,1.666293696},
      {73,1.665996224},
      {74,1.665706893},
      {75,1.665425373},
      {76,1.665151353},
      {77,1.664884537},
      {78,1.664624644},
      {79,1.664371409},
      {80,1.664124579},
      {81,1.663883913},
      {82,1.663649184},
      {83,1.663420175},
      {84,1.663196679},
      {85,1.6629785},
      {86,1.662765449},
      {87,1.662557349},
      {88,1.662354029},
      {89,1.662155326},
      {90,1.661961084},
      {91,1.661771155},
      {92,1.661585397},
      {93,1.661403674},
      {94,1.661225855},
      {95,1.661051817},
      {96,1.66088144},
      {97,1.66071461},
      {98,1.660551217},
      {99,1.660391156},
      {100,1.660234326},
      {101,1.66008063},
      {102,1.659929976},
      {103,1.659782273},
      {104,1.659637437},
      {105,1.659495383},
      {106,1.659356034},
      {107,1.659219312},
      {108,1.659085144},
      {109,1.658953458},
      {110,1.658824187},
      {111,1.658697265},
      {112,1.658572629},
      {113,1.658450216},
      {114,1.658329969},
      {115,1.65821183},
      {116,1.658095744},
      {117,1.657981659},
      {118,1.657869522},
      {119,1.657759285},
      {120,1.657650899},
      {121,1.657544319},
      {122,1.657439499},
      {123,1.657336397},
      {124,1.65723497},
      {125,1.657135178},
      {126,1.657036982},
      {127,1.656940344},
      {128,1.656845226},
      {129,1.656751594},
      {130,1.656659413},
      {131,1.656568649},
      {132,1.65647927},
      {133,1.656391244},
      {134,1.656304542},
      {135,1.656219133},
      {136,1.656134988},
      {137,1.65605208},
      {138,1.655970382},
      {139,1.655889868},
      {140,1.655810511},
      {141,1.655732287},
      {142,1.655655173},
      {143,1.655579143},
      {144,1.655504177},
      {145,1.655430251},
      {146,1.655357345},
      {147,1.655285437},
      {148,1.655214506},
      {149,1.655144534},
      {150,1.6550755},
      {151,1.655007387},
      {152,1.654940175},
      {153,1.654873847},
      {154,1.654808385},
      {155,1.654743774},
      {156,1.654679996},
      {157,1.654617035},
      {158,1.654554875},
      {159,1.654493503},
      {160,1.654432901},
      {161,1.654373057},
      {162,1.654313957},
      {163,1.654255585},
      {164,1.654197929},
      {165,1.654140976},
      {166,1.654084713},
      {167,1.654029128},
      {168,1.653974208},
      {169,1.653919942},
      {170,1.653866317},
      {171,1.653813324},
      {172,1.653760949},
      {173,1.653709184},
      {174,1.653658017},
      {175,1.653607437},
      {176,1.653557435},
      {177,1.653508002},
      {178,1.653459126},
      {179,1.6534108},
      {180,1.653363013},
      {181,1.653315758},
      {182,1.653269024},
      {183,1.653222803},
      {184,1.653177088},
      {185,1.653131869},
      {186,1.653087138},
      {187,1.653042889},
      {188,1.652999113},
      {189,1.652955802},
      {190,1.652912949},
      {191,1.652870547},
      {192,1.652828589},
      {193,1.652787068},
      {194,1.652745977},
      {195,1.65270531},
      {196,1.652665059},
      {197,1.652625219},
      {198,1.652585784},
      {199,1.652546746},
      {200,1.652508101},
      {201,1.652469842},
      {202,1.652431964},
      {203,1.65239446},
      {204,1.652357326},
      {205,1.652320556},
      {206,1.652284144},
      {207,1.652248086},
      {208,1.652212376},
      {209,1.652177009},
      {210,1.652141981},
      {211,1.652107286},
      {212,1.65207292},
      {213,1.652038878},
      {214,1.652005156},
      {215,1.651971748},
      {216,1.651938651},
      {217,1.651905861},
      {218,1.651873373},
      {219,1.651841182},
      {220,1.651809286},
      {221,1.651777679},
      {222,1.651746359},
      {223,1.65171532},
      {224,1.65168456},
      {225,1.651654074},
      {226,1.651623859},
      {227,1.651593912},
      {228,1.651564228},
      {229,1.651534805},
      {230,1.651505638},
      {231,1.651476725},
      {232,1.651448062},
      {233,1.651419647},
      {234,1.651391475},
      {235,1.651363544},
      {236,1.65133585},
      {237,1.651308391},
      {238,1.651281164},
      {239,1.651254165},
      {240,1.651227393},
      {241,1.651200843},
      {242,1.651174514},
      {243,1.651148402},
      {244,1.651122505},
      {245,1.65109682},
      {246,1.651071345},
      {247,1.651046077},
      {248,1.651021013},
      {249,1.650996152},
      {250,1.65097149},
      {251,1.650947025},
      {252,1.650922755},
      {253,1.650898678},
      {254,1.650874791},
      {255,1.650851092},
      {256,1.650827579},
      {257,1.65080425},
      {258,1.650781102},
      {259,1.650758134},
      {260,1.650735342},
      {261,1.650712727},
      {262,1.650690284},
      {263,1.650668012},
      {264,1.65064591},
      {265,1.650623976},
      {266,1.650602207},
      {267,1.650580601},
      {268,1.650559157},
      {269,1.650537873},
      {270,1.650516748},
      {271,1.650495779},
      {272,1.650474964},
      {273,1.650454303},
      {274,1.650433793},
      {275,1.650413433},
      {276,1.65039322},
      {277,1.650373154},
      {278,1.650353233},
      {279,1.650333455},
      {280,1.650313819},
      {281,1.650294323},
      {282,1.650274966},
      {283,1.650255746},
      {284,1.650236662},
      {285,1.650217713},
      {286,1.650198896},
      {287,1.650180211},
      {288,1.650161656},
      {289,1.650143229},
      {290,1.650124931},
      {291,1.650106758},
      {292,1.650088711},
      {293,1.650070786},
      {294,1.650052985},
      {295,1.650035304},
      {296,1.650017743},
      {297,1.650000301},
      {298,1.649982976},
      {299,1.649965767},
      {300,1.649948674},
      {301,1.649931694},
      {302,1.649914828},
      {303,1.649898073},
      {304,1.649881428},
      {305,1.649864893},
      {306,1.649848466},
      {307,1.649832147},
      {308,1.649815934},
      {309,1.649799826},
      {310,1.649783823},
      {311,1.649767922},
      {312,1.649752124},
      {313,1.649736428},
      {314,1.649720831},
      {315,1.649705334},
      {316,1.649689935},
      {317,1.649674634},
      {318,1.649659429},
      {319,1.649644319},
      {320,1.649629305},
      {321,1.649614384},
      {322,1.649599556},
      {323,1.64958482},
      {324,1.649570176},
      {325,1.649555622},
      {326,1.649541157},
      {327,1.649526781},
      {328,1.649512493},
      {329,1.649498293},
      {330,1.649484178},
      {331,1.649470149},
      {332,1.649456205},
      {333,1.649442344},
      {334,1.649428567},
      {335,1.649414873},
      {336,1.64940126},
      {337,1.649387728},
      {338,1.649374276},
      {339,1.649360905},
      {340,1.649347611},
      {341,1.649334397},
      {342,1.649321259},
      {343,1.649308199},
      {344,1.649295214},
      {345,1.649282305},
      {346,1.649269471},
      {347,1.649256711},
      {348,1.649244024},
      {349,1.649231411},
      {350,1.64921887},
      {351,1.6492064},
      {352,1.649194001},
      {353,1.649181673},
      {354,1.649169415},
      {355,1.649157226},
      {356,1.649145105},
      {357,1.649133053},
      {358,1.649121068},
      {359,1.64910915},
      {360,1.649097298},
      {361,1.649085513},
      {362,1.649073792},
      {363,1.649062137},
      {364,1.649050545},
      {365,1.649039017},
      {366,1.649027553},
      {367,1.649016151},
      {368,1.649004811},
      {369,1.648993533},
      {370,1.648982315},
      {371,1.648971159},
      {372,1.648960062},
      {373,1.648949026},
      {374,1.648938048},
      {375,1.648927129},
      {376,1.648916269},
      {377,1.648905466},
      {378,1.64889472},
      {379,1.648884031},
      {380,1.648873399},
      {381,1.648862822},
      {382,1.648852302},
      {383,1.648841836},
      {384,1.648831425},
      {385,1.648821068},
      {386,1.648810764},
      {387,1.648800515},
      {388,1.648790318},
      {389,1.648780173},
      {390,1.648770081},
      {391,1.648760041},
      {392,1.648750052},
      {393,1.648740114},
      {394,1.648730226},
      {395,1.648720389},
      {396,1.648710601},
      {397,1.648700863},
      {398,1.648691174},
      {399,1.648681534},
      {400,1.648671941},
      {401,1.648662397},
      {402,1.648652901},
      {403,1.648643451},
      {404,1.648634049},
      {405,1.648624693},
      {406,1.648615383},
      {407,1.64860612},
      {408,1.648596901},
      {409,1.648587728},
      {410,1.6485786},
      {411,1.648569516},
      {412,1.648560477},
      {413,1.648551481},
      {414,1.648542529},
      {415,1.64853362},
      {416,1.648524754},
      {417,1.64851593},
      {418,1.648507149},
      {419,1.64849841},
      {420,1.648489713},
      {421,1.648481057},
      {422,1.648472442},
      {423,1.648463868},
      {424,1.648455335},
      {425,1.648446842},
      {426,1.648438388},
      {427,1.648429975},
      {428,1.648421601},
      {429,1.648413266},
      {430,1.648404969},
      {431,1.648396712},
      {432,1.648388493},
      {433,1.648380311},
      {434,1.648372168},
      {435,1.648364062},
      {436,1.648355993},
      {437,1.648347961},
      {438,1.648339967},
      {439,1.648332008},
      {440,1.648324086},
      {441,1.6483162},
      {442,1.648308349},
      {443,1.648300534},
      {444,1.648292755},
      {445,1.64828501},
      {446,1.648277301},
      {447,1.648269625},
      {448,1.648261984},
      {449,1.648254378},
      {450,1.648246805},
      {451,1.648239266},
      {452,1.64823176},
      {453,1.648224287},
      {454,1.648216847},
      {455,1.648209441},
      {456,1.648202066},
      {457,1.648194724},
      {458,1.648187415},
      {459,1.648180137},
      {460,1.64817289},
      {461,1.648165676},
      {462,1.648158492},
      {463,1.64815134},
      {464,1.648144219},
      {465,1.648137128},
      {466,1.648130068},
      {467,1.648123038},
      {468,1.648116038},
      {469,1.648109068},
      {470,1.648102128},
      {471,1.648095217},
      {472,1.648088336},
      {473,1.648081483},
      {474,1.64807466},
      {475,1.648067866},
      {476,1.6480611},
      {477,1.648054362},
      {478,1.648047653},
      {479,1.648040972},
      {480,1.648034319},
      {481,1.648027693},
      {482,1.648021096},
      {483,1.648014525},
      {484,1.648007982},
      {485,1.648001465},
      {486,1.647994976},
      {487,1.647988513},
      {488,1.647982077},
      {489,1.647975667},
      {490,1.647969283},
      {491,1.647962926},
      {492,1.647956594},
      {493,1.647950288},
      {494,1.647944008},
      {495,1.647937753},
      {496,1.647931523},
      {497,1.647925318},
      {498,1.647919139},
      {499,1.647912984},
      {500,1.647906854}
    };
  }

  const double& tValues::operator[](size_t degreeOfFreedom) const {
    return values.at(degreeOfFreedom);
  }
}