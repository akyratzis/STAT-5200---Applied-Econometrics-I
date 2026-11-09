# HW5 Q5: reproduce Lab 5's wage regressions with and without IQ.
# Run from Homework 5: Rscript R/q5_proxy_variables.R
library("sandwich");
nls80 = read.table(file.path("..", "..", "Datasets & Labs", "Lab 5",
                            "nls80.raw"));
dat = data.frame(logwage = nls80$V17, educ = nls80$V5,
                 exper = nls80$V6, tenure = nls80$V7,
                 married = nls80$V9, iq = nls80$V3);

model1 = lm(logwage ~ exper + tenure + married + educ, data = dat);
model2 = lm(logwage ~ exper + tenure + married + educ + iq, data = dat);

# Lab 5 reports coefficients, conventional SEs, and HC3 SEs for each model.
print("Model 1: without IQ");
print(cbind(Estimate = coef(model1),
            SE = sqrt(diag(vcov(model1))),
            SE_HC3 = sqrt(diag(vcovHC(model1, type = "HC3")))));
print("Model 2: with IQ");
print(cbind(Estimate = coef(model2),
            SE = sqrt(diag(vcov(model2))),
            SE_HC3 = sqrt(diag(vcovHC(model2, type = "HC3")))));

print("Education coefficient change (without minus with IQ)");
print(unname(coef(model1)["educ"] - coef(model2)["educ"]));
