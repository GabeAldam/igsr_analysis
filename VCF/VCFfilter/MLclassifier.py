'''
Created on 27 Feb 2017

@author: ernesto
'''
import pandas as pd
import numpy as np
import os
import pdb
import pickle
from sklearn import preprocessing
from sklearn.model_selection import train_test_split
from sklearn.linear_model import LogisticRegression

class MLclassifier(object):
    '''
    Class to filter a VCF using a supervised machine learning binary classifier. This class
    relies on a truth set (for example the GIAB consensus call set) that can be used to train
    the model
    '''
    def __init__(self, fitted_model=None, score=None, bcftools_folder=None):
        '''
        Constructor

        Parameters
        ----------
        fitted_model : filename, optional
                       Path to file containing the serialized fitted model
        score : float, optional
                Score of the fitted model
        bcftools_folder : str, optional
                          Path to folder containing the bcftools binary
        '''
        self.fitted_model = fitted_model
        self.bcftools_folder = bcftools_folder

    def train(self, tp_annotations, fp_annotations, outprefix, test_size=0.25):
        '''
        Function to train the binary classifier using a gold standart call set

        Parameters
        ----------
        tp_annotations : filename
                         Path to file with the variant annotations derived from the call set with the True positives
        fp_annotations : filename
                         Path to file with the variant annotations derived from the call set with the False positives
        outprefix : str
                    String used as the prefix for the fitted model
        test_size : float
                    Fraction of the initial call set that will be used for assessing the model
                    Default: 0.25
        
        Returns
        -------
        filename
                 Path to serialized fitted model
        '''

        # create 2 dataframes from tsv files
        DF_TP=pd.read_csv(tp_annotations, sep="\t", na_values=['.'])
        DF_FP=pd.read_csv(fp_annotations, sep="\t", na_values=['.'])

        DF_TP=DF_TP.assign(is_valid=1)
        DF_FP=DF_FP.assign(is_valid=0)

        frames = [DF_TP,DF_FP]
        DF = pd.concat(frames)

        # remove NA values
        DF_noNA=DF.dropna()

        # normalization of the different features
        feature_names=DF_noNA.columns.drop(['# [1]CHROM','[2]POS','is_valid'])
        std_scale = preprocessing.StandardScaler().fit(DF_noNA[feature_names])
        std_array = std_scale.transform(DF_noNA[feature_names])

        # 'preprocessing' returns a NumPy array, so we need to transform to a Pandas data frame:
        aDF_std=pd.DataFrame(data=std_array,columns=feature_names)

        # Now, let's add the column with the status of the variant( is_valid=0 or is_valid=1) to the normalized data frame
        aDF_std.insert(loc=0, column='is_valid', value=DF_noNA['is_valid'].values)

        # Let's the separate the predictors from the binary output
        predictors=aDF_std[feature_names]

        # Now, let's create a dataframe with the outcome
        outcome=aDF_std[['is_valid']]

        # Now, let's split the initial dataset into a training set that will be used to train the model and a test set,
        # which will be used to assess the performance of the fitted model
        x_train, x_test, y_train, y_test = train_test_split(predictors, outcome, test_size=test_size)

        logisticRegr = LogisticRegression(verbose=1)
        logisticRegr.fit(x_train, y_train.values.ravel())

        # Now, we can check the accuracy of our fitted model by using the `x_test` and comparing with the true outcome in `y_test`
        predictions = logisticRegr.predict(x_test)
        score = logisticRegr.score(x_test, y_test)

        print("Score for the logistic regression fitted model is: {0}".format(score))
        self.score=score

        # Model persistence
        outfile = outprefix+".sav"
        pickle.dump(logisticRegr, open(outfile, 'wb'))

        self.fitted_model=outfile

        return outfile