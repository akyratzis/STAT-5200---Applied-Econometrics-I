# Run from the Homework 6 folder.
mroz <- read.csv("Data/mroz.csv")
mroz <- subset(mroz, inlf == 1)
mroz$logwage <- mroz$lwage
mroz$exper2 <- mroz$expersq

with(mroz, {
# --- 1st stage
mm_1 = lm(educ ~ exper + exper2 + age + kidslt6 + kidsge6 + motheduc + fatheduc + huseduc);
educ_hat = matrix(mm_1$fitted.values); # xhat
# --- 2nd stage
mm2 = lm(logwage ~ exper + exper2 + age + kidslt6 + kidsge6 + educ_hat);
})
