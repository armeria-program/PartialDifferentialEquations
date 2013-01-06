\documentclass[12pt]{article}
%include polycode.fmt
\usepackage[pdftex,pagebackref,letterpaper=true,colorlinks=true,pdfpagemode=none,urlcolor=blue,linkcolor=blue,citecolor=blue,pdfstartview=FitH]{hyperref}

\usepackage{amsmath,amsfonts}
\usepackage{graphicx}
\usepackage{color}

\setlength{\oddsidemargin}{0pt}
\setlength{\evensidemargin}{0pt}
\setlength{\textwidth}{6.0in}
\setlength{\topmargin}{0in}
\setlength{\textheight}{8.5in}

\setlength{\parindent}{0in}
\setlength{\parskip}{5px}

\newcommand{\half}{\frac{1}{2}}
\newcommand{\cobind}{\mathbin{=\mkern-6.7mu>\!\!\!>}}

%format =>> = "\cobind "

\begin{document}

Now we are able to price options using parallelism, let us consider a more exotic financial option.

Let us suppose that we wish to price an Asian call option\cite{Zvan98discreteasian}. The payoff at time $T$ is

$$
{\Bigg(\frac{\Sigma_{i=1}^n S_{t_i}}{n} -k\Bigg)}^+
$$

Thus the payoff depends not just on the value of the underlying $S$ at
time $T$ but also on the path taken. We do not need to know the entire path, just the average at discrete points in time. Thus the payoff is a function of time, the value of the underlying and the average of the underlying sampled at discrete points in time $z(x,a,t)$.



\begin{code}
{-# LANGUAGE FlexibleContexts, TypeOperators #-}

{-# OPTIONS_GHC -Wall -fno-warn-name-shadowing -fno-warn-type-defaults #-}
    
import Data.Array.Repa as Repa
import Control.Monad

r, sigma, k, t, xMax, deltaX, deltaT :: Double
m, n, p :: Int
r = 0.05
sigma = 0.2
k = 50.0
t = 3.0
m = 80
p = 99
xMax = 150
deltaX = xMax / (fromIntegral m)
n = 800
deltaT = t / (fromIntegral n)

singleUpdater :: Array D DIM1 Double -> Array D DIM1 Double
singleUpdater a = traverse a id f
  where
    Z :. m = extent a
    f _get (Z :. ix) | ix == 0   = 0.0
    f _get (Z :. ix) | ix == m-1 = xMax - k
    f  get (Z :. ix)             = a * get (Z :. ix-1) +
                                   b * get (Z :. ix) +
                                   c * get (Z :. ix+1)
      where
        a = deltaT * (sigma^2 * (fromIntegral ix)^2 - r * (fromIntegral ix)) / 2
        b = 1 - deltaT * (r  + sigma^2 * (fromIntegral ix)^2)
        c = deltaT * (sigma^2 * (fromIntegral ix)^2 + r * (fromIntegral ix)) / 2

priceAtT :: Array U DIM1 Double
priceAtT = fromListUnboxed (Z :. m+1) [max 0 (deltaX * (fromIntegral j) - k) | j <- [0..m]]

multiUpdater :: Source r Double => Array r DIM2 Double -> Array D DIM2 Double
multiUpdater a = fromFunction (extent a) f
     where
       f :: DIM2 -> Double
       f (Z :. ix :. jx) = (singleUpdater x)!(Z :. ix)
         where
           x :: Array D DIM1 Double
           x = slice a (Any :. jx)

priceAtTMulti :: Array U DIM2 Double
priceAtTMulti = fromListUnboxed (Z :. m+1 :. p+1)
                [ max 0 (deltaX * (fromIntegral j) - (k + (fromIntegral l)/1000.0))
                | j <- [0..m]
                , l <- [0..p]
                ]

testMulti :: IO (Array U DIM2 Double)
testMulti = updaterM priceAtTMulti
  where
    updaterM :: Monad m => Array U DIM2 Double -> m (Array U DIM2 Double)
    updaterM = foldr (>=>) return (replicate n (computeP . multiUpdater))

pickAtStrike :: Monad m => Int -> Array U DIM2 Double -> m (Array U DIM1 Double)
pickAtStrike n t = computeP $ slice t (Any :. n :. All)

main :: IO ()
main = do t <- testMulti
          vStrikes <- pickAtStrike 27 t
          putStrLn $ show vStrikes

data PointedArrayP a = PointedArrayP Int (Array U DIM2 a)
  deriving Show

priceAtTP2 :: PointedArrayP Double
priceAtTP2 =
  PointedArrayP 0 (fromListUnboxed (Z :. m+1 :. p+1) 
                [ max 0 (deltaX * (fromIntegral j) - k) | j <- [0..m], _l <- [0..p] ])

fP :: PointedArrayP Double -> Array D DIM1 Double
fP (PointedArrayP j _x) | j == 0 = fromFunction (Z :. p+1) (const 0.0)
fP (PointedArrayP j _x) | j == m = fromFunction (Z :. p+1) (const $ xMax - k)
fP (PointedArrayP j  x)          = (lift a) *^ (slice x (Any :. j-1 :. All)) +^
                                   (lift b) *^ (slice x (Any :. j   :. All)) +^
                                   (lift c) *^ (slice x (Any :. j+1 :. All))
  where
    a = deltaT * (sigma^2 * (fromIntegral j)^2 - r * (fromIntegral j)) / 2
    b = 1 - deltaT * (r  + sigma^2 * (fromIntegral j)^2)
    c = deltaT * (sigma^2 * (fromIntegral j)^2 + r * (fromIntegral j)) / 2

    lift x = fromFunction (Z :. p+1) (const x)

priceAtTA :: Array U (Z :. Int) Double
priceAtTA = fromListUnboxed (Z :. m+1) [max 0 (deltaX * (fromIntegral j) - k) | j <- [0..m]]

multiUpdater2 :: Array D DIM2 Double -> Array D DIM2 Double
multiUpdater2 a = fromFunction (extent a) f
     where
       f :: DIM2 -> Double
       f (Z :. ix :. jx) = (singleUpdater x)!(Z :. jx)
         where
           x :: Array D DIM1 Double
           x = slice a (Any :. ix :. All)
\end{code}

\end{document}