import React from 'react';
import { useSelector } from 'react-redux';
import {
	DropdownItem
} from '@patternfly/react-core/deprecated';
import { SecurityIcon } from '@patternfly/react-icons';
import { selectAPIResponse } from 'foremanReact/redux/API/APISelectors';
import { useAPI } from 'foremanReact/common/hooks/API/APIHooks';
import { translate as __ } from 'foremanReact/common/I18n';
import { HOST_DETAILS_KEY } from 'foremanReact/components/HostDetails/consts';
import { foremanUrl } from 'foremanReact/common/helpers';

const HostKebabItems = () => {
  const { name, id } = useSelector(state =>
    selectAPIResponse(state, HOST_DETAILS_KEY)
  );

  const ARFReportsAPIPath = name
    ? `/api/v2/compliance/arf_reports?search=host+%3D+${name}`
    : null;

  const {
    response: { results = [] },
  } = useAPI('get', ARFReportsAPIPath);

  const compliancePath = foremanUrl(`/compliance/hosts/${id}`);

  const isDisabled = results.length === 0;

  return (
    <DropdownItem
      ouiaId="compliance-dropdown-item"
      key="compliance-report"
      icon={<SecurityIcon />}
      href={compliancePath}
      target="_blank"
      rel="noreferrer"
      isAriaDisabled={isDisabled}
      tooltip={isDisabled && __("There's no available report for this host")}
    >
      {__('Compliance')}
    </DropdownItem>
  );
};

export default HostKebabItems;
