import React from 'react';
import {
	Button
} from '@patternfly/react-core';
import {
	WizardFooter,
	WizardContextConsumer
} from '@patternfly/react-core/deprecated';
import { translate as __ } from 'foremanReact/common/I18n';
import { WIZARD_TITLES } from './constants';

export const Footer = () => (
  <WizardFooter>
    <WizardContextConsumer>
      {({ activeStep, onNext, onBack, onClose, goToStepByName }) => {
        const isValid =
          activeStep && activeStep.enableNext !== undefined
            ? activeStep.enableNext
            : true;

        return (
          <>
            {!activeStep.isFinishedStep ? (
              <Button
                ouiaId="oscap-rem-wiz-next-button"
                variant="primary"
                type="submit"
                onClick={onNext}
                isDisabled={!isValid}
              >
                {activeStep.name === WIZARD_TITLES.reviewRemediation
                  ? __('Run')
                  : __('Next')}
              </Button>
            ) : null}
            <Button
              ouiaId="oscap-rem-wiz-back-button"
              variant="secondary"
              onClick={onBack}
              isDisabled={activeStep.name === WIZARD_TITLES.snippetSelect}
            >
              {__('Back')}
            </Button>
            <Button
              ouiaId="oscap-rem-wiz-cancel-button"
              variant="link"
              onClick={onClose}
            >
              {__('Cancel')}
            </Button>
          </>
        );
      }}
    </WizardContextConsumer>
  </WizardFooter>
);
