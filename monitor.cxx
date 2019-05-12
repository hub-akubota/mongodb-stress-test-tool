#include <iostream>
#include <fstream>
#include <TStyle.h>
#include <TCanvas.h>
#include <TGraph.h>

int monitor(){
    ifstream ifs("size.dat");
    const int value = 11;
    int cnt = 1;
    int count = 1;
    std::vector<double> counts;
    std::vector<double> storageSize;
    while(true) {
        std::string tmp;
        ifs >> tmp;
        if (ifs.eof()) break;
        if (cnt == 2) storageSize.push_back(atof(tmp.c_str()));
        if (cnt == value) {
            counts.push_back(count);
            cnt = 0;
            count++;
        }
        cnt++;
    }
    TCanvas* c1 = new TCanvas("c1");
    TGraph* graph = new TGraph(storageSize.size(), &counts[0], &storageSize[0]);
    graph->Draw("AP");
    c1->Print("test.pdf");   
    return 0;
}
