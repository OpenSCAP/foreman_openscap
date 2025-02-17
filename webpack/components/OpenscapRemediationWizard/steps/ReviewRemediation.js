/* eslint-disable camelcase */
import React, { useContext, useState } from 'react';
import { some } from 'lodash';
import {
  CodeBlock,
  CodeBlockAction,
  CodeBlockCode,
  ClipboardCopyButton,
  Button,
  Grid,
  GridItem,
  Alert,
  Checkbox,
} from '@patternfly/react-core';
import { ExternalLinkSquareAltIcon } from '@patternfly/react-icons';

import { translate as __ } from 'foremanReact/common/I18n';
import { foremanUrl } from 'foremanReact/common/helpers';
import {
  useForemanHostsPageUrl,
  useForemanHostDetailsPageUrl,
} from 'foremanReact/Root/Context/ForemanContext';

import OpenscapRemediationWizardContext from '../OpenscapRemediationWizardContext';
import WizardHeader from '../WizardHeader';
import ViewSelectedHostsLink from '../ViewSelectedHostsLink';
import { FAIL_RULE_SEARCH } from '../constants';
import { findFixBySnippet } from '../helpers';

import './ReviewRemediation.scss';

const ReviewRemediation = () => {
  const {
    fixes,
    snippet,
    method,
    hostName,
    source,
    isRebootSelected,
    setIsRebootSelected,
    isAllHostsSelected,
    hostIdsParam,
    defaultFailedHostsSearch,
  } = useContext(OpenscapRemediationWizardContext);
  const [copied, setCopied] = useState(false);
  const selectedFix = findFixBySnippet(fixes, snippet);
  const snippetText = selectedFix?.full_text;
  // can be one of null, "true", "false"
  // if null, it may indicate that reboot might be needed
  const checkForReboot = () => !some(fixes, { reboot: 'false' });
  const isRebootRequired = () => some(fixes, { reboot: 'true' });

  const copyToClipboard = (e, text) => {
    navigator.clipboard.writeText(text.toString());
  };

  const onCopyClick = (e, text) => {
    copyToClipboard(e, text);
    setCopied(true);
  };

  const description =
    method === 'manual'
      ? __('Review the remediation snippet and apply it to the host manually.')
      : __(
          'Review the remediation snippet that will be applied to selected host(s).'
        );

  const rebootAlertTitle = isRebootRequired()
    ? __('A reboot is required after applying remediation.')
    : __('A reboot might be required after applying remediation.');

  const actions = (
    <React.Fragment>
      <CodeBlockAction>
        <ClipboardCopyButton
          id="basic-copy-button"
          textId="code-content"
          aria-label="Copy to clipboard"
          onClick={e => onCopyClick(e, snippetText)}
          exitDelay={copied ? 1500 : 600}
          maxWidth="110px"
          variant="plain"
          onTooltipHidden={() => setCopied(false)}
        >
          {copied
            ? __('Successfully copied to clipboard!')
            : __('Copy to clipboard')}
        </ClipboardCopyButton>
      </CodeBlockAction>
    </React.Fragment>
  );

  return (
    <>
      <WizardHeader
        title={__('Review remediation')}
        description={description}
      />
      <Grid hasGutter>
        <br />
        <GridItem>
          <Alert
            ouiaId="review-alert"
            variant="danger"
            title={`${__(
              'Do not implement any of the recommended remedial actions or scripts without first testing them in a non-production environment.'
            )}
              ${__('Remediation might render the system non-functional.')}`}
          />
        </GridItem>
        <GridItem md={12} span={4} rowSpan={1}>
          <ViewSelectedHostsLink
            isAllHostsSelected={isAllHostsSelected}
            hostIdsParam={hostIdsParam}
            defaultFailedHostsSearch={defaultFailedHostsSearch}
          />
        </GridItem>
        <GridItem md={12} span={4} rowSpan={1}>
          <Button
            ouiaId={`oscap-wiz-host-details-button-${hostName}-revrem-step`}
            variant="link"
            icon={<ExternalLinkSquareAltIcon />}
            iconPosition="right"
            target="_blank"
            component="a"
            href={foremanUrl(`${useForemanHostDetailsPageUrl()}${hostName}`)}
          >
            {hostName}
          </Button>{' '}
        </GridItem>
        <GridItem md={12} span={8} rowSpan={1}>
          <Button
            ouiaId={`oscap-wiz-ext-link-to-hosts-${source}-revrem-step`}
            variant="link"
            icon={<ExternalLinkSquareAltIcon />}
            iconPosition="right"
            target="_blank"
            component="a"
            href={foremanUrl(
              `${useForemanHostsPageUrl()}?search=${FAIL_RULE_SEARCH} = ${source}`
            )}
          >
            {__('Other hosts failing this rule')}
          </Button>
        </GridItem>
        {checkForReboot() ? (
          <>
            <GridItem span={12} rowSpan={1}>
              <Alert
                ouiaId="reboot-alert"
                variant={isRebootRequired() ? 'warning' : 'info'}
                title={rebootAlertTitle}
              />
            </GridItem>
            {method === 'manual' ? null : (
              <GridItem span={4} rowSpan={1}>
                <Checkbox
                  ouiaId="oscap-wiz-reboot-checkbox-revrem-step"
                  id="reboot-checkbox"
                  label={__('Reboot the system(s)')}
                  name="reboot-checkbox"
                  isChecked={isRebootSelected}
                  onChange={(_event, selected) => setIsRebootSelected(selected)}
                />
              </GridItem>
            )}
          </>
        ) : null}
        <GridItem>
          <CodeBlock actions={actions}>
            <CodeBlockCode id="code-content" className="remediation-code">
              {snippetText}
            </CodeBlockCode>
          </CodeBlock>
        </GridItem>
      </Grid>
    </>
  );
};

export default ReviewRemediation;
