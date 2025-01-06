import React, { useContext } from 'react';
import { map, split, capitalize, join, slice, isEmpty } from 'lodash';
import {
  Form,
  FormGroup,
  FormSelect,
  FormSelectOption,
  Radio,
  Alert,
} from '@patternfly/react-core';

import { translate as __ } from 'foremanReact/common/I18n';
import { STATUS } from 'foremanReact/constants';
import Loading from 'foremanReact/components/Loading';

import OpenscapRemediationWizardContext from '../OpenscapRemediationWizardContext';
import WizardHeader from '../WizardHeader';
import EmptyState from '../../EmptyState';
import { errorMsg, supportedRemediationSnippets } from '../helpers';

const SnippetSelect = () => {
  const {
    fixes,
    snippet,
    setSnippet,
    method,
    setMethod,
    logStatus,
    logError,
    supportedJobSnippets,
  } = useContext(OpenscapRemediationWizardContext);

  const snippetNameMap = {
    'urn:xccdf:fix:script:ansible': 'Ansible',
    'urn:xccdf:fix:script:puppet': 'Puppet',
    'urn:xccdf:fix:script:sh': 'Shell',
    'urn:xccdf:fix:script:kubernetes': 'Kubernetes',
    'urn:redhat:anaconda:pre': 'Anaconda',
    'urn:redhat:osbuild:blueprint': 'OSBuild Blueprint',
  };

  const snippetName = system => {
    const mapped = snippetNameMap[system];
    if (mapped) return mapped;

    return join(
      map(slice(split(system, ':'), -2), n => capitalize(n)),
      ' '
    );
  };

  const resetSnippet = meth => {
    const snip = supportedRemediationSnippets(
      fixes,
      meth,
      supportedJobSnippets
    )[0];
    setSnippet(snip);
    return snip;
  };

  const setMethodResetSnippet = meth => {
    setMethod(meth);
    resetSnippet(meth);
  };

  const body =
    logStatus === STATUS.RESOLVED ? (
      <Form>
        <FormGroup
          label={__('Method')}
          type="string"
          fieldId="method"
          isRequired={false}
        >
          <Radio
            label={__('Remote job')}
            id="job"
            name="job"
            ouiaId="job"
            aria-label="job"
            isChecked={method === 'job'}
            onChange={() => setMethodResetSnippet('job')}
          />
          <Radio
            label={__('Manual')}
            id="manual"
            name="manual"
            ouiaId="manual"
            aria-label="manual"
            isChecked={method === 'manual'}
            onChange={() => setMethodResetSnippet('manual')}
          />
        </FormGroup>
        {isEmpty(
          supportedRemediationSnippets(fixes, method, supportedJobSnippets)
        ) ? (
          <Alert
            ouiaId="snippet-alert"
            variant="info"
            title={__(
              'There is no job to remediate with. Please remediate manually.'
            )}
          />
        ) : (
          <FormGroup
            label={__('Snippet')}
            type="string"
            fieldId="snippet"
            isRequired
          >
            <FormSelect
              ouiaId="snippet-select"
              isRequired
              value={snippet}
              onChange={(_event, value) => setSnippet(value)}
              aria-label="FormSelect Input"
            >
              <FormSelectOption
                isDisabled
                key={0}
                value=""
                label={__('Select snippet')}
              />
              {map(
                supportedRemediationSnippets(
                  fixes,
                  method,
                  supportedJobSnippets
                ),
                fix => (
                  <FormSelectOption
                    key={fix}
                    value={fix}
                    label={snippetName(fix)}
                  />
                )
              )}
            </FormSelect>
          </FormGroup>
        )}
      </Form>
    ) : (
      <EmptyState
        ouiaEmptyStateTitleId="oscap-rem-wiz-empty-state-title"
        error
        title={__('Error!')}
        body={errorMsg(logError)}
      />
    );

  return (
    <>
      <WizardHeader
        title={__('Select remediation method')}
        description={__(
          'You can remediate by running a remote job or you can display a snippet for manual remediation.'
        )}
      />
      {logStatus === STATUS.PENDING ? <Loading /> : body}
    </>
  );
};

export default SnippetSelect;
