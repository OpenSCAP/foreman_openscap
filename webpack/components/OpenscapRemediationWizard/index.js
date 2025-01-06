import React, { useState, useRef } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import PropTypes from 'prop-types';
import {
	Button
} from '@patternfly/react-core';
import {
	Wizard
} from '@patternfly/react-core/deprecated';

import { sprintf, translate as __ } from 'foremanReact/common/I18n';
import { API_OPERATIONS, get } from 'foremanReact/redux/API';

import OpenscapRemediationWizardContext from './OpenscapRemediationWizardContext';
import { Footer } from './Footer';
import {
  selectLogResponse,
  selectLogError,
  selectLogStatus,
} from './OpenscapRemediationSelectors';
import {
  REPORT_LOG_REQUEST_KEY,
  FAIL_RULE_SEARCH,
  WIZARD_TITLES,
} from './constants';
import { SnippetSelect, ReviewHosts, ReviewRemediation, Finish } from './steps';

const OpenscapRemediationWizard = ({
  report_id: reportId,
  host: { id: hostId, name: hostName },
  supported_remediation_snippets: supportedJobSnippets,
}) => {
  const dispatch = useDispatch();
  const log = useSelector(state => selectLogResponse(state))?.log;
  const logStatus = useSelector(state => selectLogStatus(state));
  const logError = useSelector(state => selectLogError(state));

  const fixes = JSON.parse(log?.message?.fixes || null) || [];
  const source = log?.source?.value || '';
  const title = log?.message?.value || '';
  const defaultHostIdsParam = `id ^ (${hostId})`;
  const defaultFailedHostsSearch = `${FAIL_RULE_SEARCH} = ${source}`;

  const [isRemediationWizardOpen, setIsRemediationWizardOpen] = useState(false);
  const [snippet, setSnippet] = useState('');
  const [method, setMethod] = useState('job');
  const [hostIdsParam, setHostIdsParam] = useState(defaultHostIdsParam);
  const [isRebootSelected, setIsRebootSelected] = useState(false);
  const [isAllHostsSelected, setIsAllHostsSelected] = useState(false);

  const savedHostSelectionsRef = useRef({});

  const onModalButtonClick = e => {
    e.preventDefault();
    const logId = e.target.getAttribute('data-log-id');
    dispatch(
      get({
        type: API_OPERATIONS.GET,
        key: REPORT_LOG_REQUEST_KEY,
        url: `/compliance/arf_reports/${reportId}/show_log`,
        params: { log_id: logId },
      })
    );
    setIsRemediationWizardOpen(true);
  };

  const onWizardClose = () => {
    // Reset to defaults
    setHostIdsParam(defaultHostIdsParam);
    setSnippet('');
    setMethod('job');
    setIsRebootSelected(false);
    setIsRemediationWizardOpen(false);
    savedHostSelectionsRef.current = {};
  };

  const reviewHostsStep = {
    id: 2,
    name: WIZARD_TITLES.reviewHosts,
    component: <ReviewHosts />,
    canJumpTo: Boolean(snippet && method === 'job'),
    enableNext: Boolean(snippet && method),
  };
  const steps = [
    {
      id: 1,
      name: WIZARD_TITLES.snippetSelect,
      component: <SnippetSelect />,
      canJumpTo: true,
      enableNext: Boolean(snippet && method),
    },
    ...(snippet && method === 'job' ? [reviewHostsStep] : []),
    {
      id: 3,
      name: WIZARD_TITLES.reviewRemediation,
      component: <ReviewRemediation />,
      canJumpTo: Boolean(snippet && method),
      enableNext: method === 'job',
      nextButtonText: __('Run'),
    },
    {
      id: 4,
      name: WIZARD_TITLES.finish,
      component: <Finish onClose={onWizardClose} />,
      isFinishedStep: true,
    },
  ];

  return (
    <>
      {isRemediationWizardOpen && (
        <OpenscapRemediationWizardContext.Provider
          value={{
            fixes,
            snippet,
            setSnippet,
            method,
            setMethod,
            hostName,
            source,
            logStatus,
            logError,
            supportedJobSnippets,
            isRebootSelected,
            setIsRebootSelected,
            hostId,
            hostIdsParam,
            setHostIdsParam,
            isAllHostsSelected,
            setIsAllHostsSelected,
            defaultFailedHostsSearch,
            savedHostSelectionsRef,
          }}
        >
          <Wizard
            title={title}
            description={sprintf(__('Remediate %s rule'), source)}
            isOpen={isRemediationWizardOpen}
            steps={steps}
            onClose={onWizardClose}
            footer={<Footer />}
          />
        </OpenscapRemediationWizardContext.Provider>
      )}
      <Button
        ouiaId="oscap-rem-wiz-open-wiz-button"
        id="openscapRemediationWizardButton"
        variant="link"
        isInline
        component="span"
        onClick={e => onModalButtonClick(e)}
      />
    </>
  );
};

OpenscapRemediationWizard.propTypes = {
  report_id: PropTypes.oneOfType([PropTypes.number, PropTypes.string]),
  host: PropTypes.shape({
    id: PropTypes.oneOfType([PropTypes.number, PropTypes.string]),
    name: PropTypes.string,
  }),
  supported_remediation_snippets: PropTypes.array,
};

OpenscapRemediationWizard.defaultProps = {
  report_id: '',
  host: {},
  supported_remediation_snippets: [],
};

export default OpenscapRemediationWizard;
