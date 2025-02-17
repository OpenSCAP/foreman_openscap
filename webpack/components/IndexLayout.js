import React from 'react';
import PropTypes from 'prop-types';
import { Helmet } from 'react-helmet';
import ToastsList from 'foremanReact/components/ToastsList';
import {
  Grid,
  GridItem,
  TextContent,
  Text,
  TextVariants,
} from '@patternfly/react-core';

import './IndexLayout.scss';

const IndexLayout = ({ pageTitle, children, contentWidthSpan }) => (
  <React.Fragment>
    <Helmet>
      <title>{pageTitle}</title>
    </Helmet>
    <ToastsList />
    <Grid className="scap-page-grid">
      <GridItem span={12} className="pf-v5-u-pb-xl">
        <TextContent>
          <Text ouiaId="oscap-index-title" component={TextVariants.h1}>
            {pageTitle}
          </Text>
        </TextContent>
      </GridItem>
      <GridItem span={contentWidthSpan}>{children}</GridItem>
    </Grid>
  </React.Fragment>
);

IndexLayout.propTypes = {
  pageTitle: PropTypes.string.isRequired,
  children: PropTypes.oneOfType([PropTypes.node, PropTypes.object]).isRequired,
  contentWidthSpan: PropTypes.number,
};

IndexLayout.defaultProps = {
  contentWidthSpan: 12,
};

export default IndexLayout;
